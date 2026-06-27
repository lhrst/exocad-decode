// decode_scene.cs — 用 exocad 自己的 DLL 把 .dentalCAD 里的网格解出来。
//
// 思路: BinaryFormatter.Deserialize 整个 .dentalCAD, DentalBaseDotNet.dll 的
// OnDeserializeDentalBaseNatives 回调会自动解码 SBUF blob -> 顶点/面.
// 然后反射遍历对象图, 把每个 mesh 写成 STL.
//
// 编译(需 .NET Framework 4.8, 因为 BinaryFormatter 在 .NET 5+ 被弃用):
//   csc /reference:DentalBaseDotNet.dll /reference:DentalData.dll decode_scene.cs
// 运行(同目录放齐 exocad 的 DLL + native 依赖):
//   decode_scene.exe  path\to\xxx.dentalCAD  out_dir
//
// 注意: 字段/类型名(Scene/Jaw/ViewerObject/mesh accessor)需按实际 DLL 反射结果微调,
//       下方用反射 + 启发式搜索"看起来像顶点/面数组"的成员, 尽量自适应.

using System;
using System.Collections;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Runtime.Serialization.Formatters.Binary;

class DecodeScene
{
    [DllImport("kernel32", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr LoadLibrary(string lpFileName);

    static void Main(string[] args)
    {
        if (args.Length < 2) { Console.WriteLine("usage: decode_scene <file.dentalCAD> <outdir>"); return; }
        string path = args[0], outdir = args[1];
        Directory.CreateDirectory(outdir);

        // 关键: 先用 native LoadLibrary 预加载 mixed-mode DLL (native 上下文,
        // 像 exe 启动那样过 native init), 避开 CLR 反序列化触发加载时的崩溃.
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        foreach (var dll in new[] { "DentalBaseExternals64.dll", "DentalBaseDicom64.dll",
                                    "DentalData.dll", "DentalBaseDotNet.dll" })
        {
            string dp = Path.Combine(dir, dll);
            if (File.Exists(dp))
            {
                IntPtr h = LoadLibrary(dp);
                Console.WriteLine($"LoadLibrary {dll}: " + (h == IntPtr.Zero ? "FAIL " + Marshal.GetLastWin32Error() : "ok"));
            }
        }

        // 让 BinaryFormatter 能解析 exocad 的程序集
        AppDomain.CurrentDomain.AssemblyResolve += (s, e) => {
            string n = new AssemblyName(e.Name).Name + ".dll";
            string p = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, n);
            return File.Exists(p) ? Assembly.LoadFrom(p) : null;
        };

        object scene;
        using (var fs = File.OpenRead(path))
        {
#pragma warning disable SYSLIB0011
            var bf = new BinaryFormatter();
            scene = bf.Deserialize(fs);   // <-- DentalBaseDotNet 在此自动解码 SBUF 网格
#pragma warning restore SYSLIB0011
        }
        Console.WriteLine("Deserialized root: " + scene.GetType().FullName);

        int meshIdx = 0;
        var seen = new System.Collections.Generic.HashSet<object>();
        Walk(scene, outdir, ref meshIdx, seen, 0);
        Console.WriteLine($"Done. {meshIdx} mesh(es) written to {outdir}");
    }

    // 递归遍历对象图, 找到 (float[] 顶点 + int[] 三角形) 的组合就导出 STL
    static void Walk(object obj, string outdir, ref int idx, System.Collections.Generic.HashSet<object> seen, int depth)
    {
        if (obj == null || depth > 40) return;
        var t = obj.GetType();
        if (t.IsPrimitive || obj is string) return;
        if (!t.IsValueType) { if (seen.Contains(obj)) return; seen.Add(obj); }

        // 启发式: 一个对象若同时持有大 float[](xyz) 和 int[](面索引) -> 当作 mesh
        float[] verts = null; int[] faces = null;
        foreach (var f in t.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
        {
            object v; try { v = f.GetValue(obj); } catch { continue; }
            if (v is float[] fa && fa.Length >= 9 && fa.Length % 3 == 0 && verts == null) verts = fa;
            else if (v is double[] da && da.Length >= 9 && da.Length % 3 == 0 && verts == null) { verts = new float[da.Length]; for (int i=0;i<da.Length;i++) verts[i]=(float)da[i]; }
            else if (v is int[] ia && ia.Length >= 3 && ia.Length % 3 == 0 && faces == null) faces = ia;
            else if (v is uint[] ua && ua.Length >= 3 && ua.Length % 3 == 0 && faces == null) { faces = new int[ua.Length]; for (int i=0;i<ua.Length;i++) faces[i]=(int)ua[i]; }
        }
        if (verts != null && faces != null && verts.Length/3 > 50 && faces.Length/3 > 50)
        {
            string fn = Path.Combine(outdir, $"mesh_{idx:00}_v{verts.Length/3}_f{faces.Length/3}.stl");
            WriteStl(fn, verts, faces);
            Console.WriteLine($"  mesh[{idx}] verts={verts.Length/3} faces={faces.Length/3} -> {fn}");
            idx++;
        }

        // 继续递归字段 / 集合元素
        if (obj is IEnumerable en && !(obj is string))
            foreach (var item in en) Walk(item, outdir, ref idx, seen, depth + 1);
        foreach (var f in t.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
        {
            if (f.FieldType.IsPrimitive || f.FieldType == typeof(string)) continue;
            object v; try { v = f.GetValue(obj); } catch { continue; }
            Walk(v, outdir, ref idx, seen, depth + 1);
        }
    }

    static void WriteStl(string path, float[] v, int[] f)
    {
        using (var bw = new BinaryWriter(File.Create(path)))
        {
            bw.Write(new byte[80]);
            bw.Write((uint)(f.Length / 3));
            for (int i = 0; i < f.Length; i += 3)
            {
                bw.Write(0f); bw.Write(0f); bw.Write(0f); // normal (0, 阅读器会重算)
                for (int k = 0; k < 3; k++)
                {
                    int idx = f[i + k] * 3;
                    bw.Write(v[idx]); bw.Write(v[idx + 1]); bw.Write(v[idx + 2]);
                }
                bw.Write((ushort)0);
            }
        }
    }
}
