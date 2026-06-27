// decode_scene.cs — 用 exocad 自己的 DLL 把 .dentalCAD 里的网格解出来 (C# 5 兼容)
// BinaryFormatter.Deserialize 整个 .dentalCAD -> DentalBaseDotNet 自动解码 SBUF -> 反射找 mesh -> STL
using System;
using System.Collections;
using System.Collections.Generic;
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

        string dir = AppDomain.CurrentDomain.BaseDirectory;
        foreach (string dll in new string[] { "DentalBaseExternals64.dll", "DentalBaseDicom64.dll",
                                              "DentalData.dll", "DentalBaseDotNet.dll" })
        {
            string dp = Path.Combine(dir, dll);
            if (File.Exists(dp))
            {
                IntPtr h = LoadLibrary(dp);
                Console.WriteLine("LoadLibrary " + dll + ": " + (h == IntPtr.Zero ? "FAIL " + Marshal.GetLastWin32Error() : "ok"));
            }
        }

        AppDomain.CurrentDomain.AssemblyResolve += delegate(object s, ResolveEventArgs e) {
            string n = new AssemblyName(e.Name).Name + ".dll";
            string p = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, n);
            try { return File.Exists(p) ? Assembly.LoadFrom(p) : null; } catch { return null; }
        };

        // 预加载目录下所有 .NET 程序集, 让 BinaryFormatter 直接找到(native dll 会 catch 跳过)
        foreach (string dll in Directory.GetFiles(dir, "*.dll"))
        {
            try { Assembly.LoadFrom(dll); } catch { }
        }

        object scene;
        using (FileStream fs = File.OpenRead(path))
        {
            BinaryFormatter bf = new BinaryFormatter();
            scene = bf.Deserialize(fs);   // DentalBaseDotNet 在此自动解码 SBUF 网格
        }
        Console.WriteLine("Deserialized root: " + scene.GetType().FullName);

        int meshIdx = 0;
        HashSet<object> seen = new HashSet<object>();
        Walk(scene, outdir, ref meshIdx, seen, 0);
        Console.WriteLine("Done. " + meshIdx + " mesh(es) written to " + outdir);
    }

    static void Walk(object obj, string outdir, ref int idx, HashSet<object> seen, int depth)
    {
        if (obj == null || depth > 40) return;
        Type t = obj.GetType();
        if (t.IsPrimitive || obj is string) return;
        if (!t.IsValueType) { if (seen.Contains(obj)) return; seen.Add(obj); }

        float[] verts = null; int[] faces = null;
        foreach (FieldInfo f in t.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
        {
            object v; try { v = f.GetValue(obj); } catch { continue; }
            if (v == null) continue;
            float[] fa = v as float[];
            double[] da = v as double[];
            int[] ia = v as int[];
            uint[] ua = v as uint[];
            if (fa != null && fa.Length >= 9 && fa.Length % 3 == 0 && verts == null) verts = fa;
            else if (da != null && da.Length >= 9 && da.Length % 3 == 0 && verts == null) { verts = new float[da.Length]; for (int i = 0; i < da.Length; i++) verts[i] = (float)da[i]; }
            else if (ia != null && ia.Length >= 3 && ia.Length % 3 == 0 && faces == null) faces = ia;
            else if (ua != null && ua.Length >= 3 && ua.Length % 3 == 0 && faces == null) { faces = new int[ua.Length]; for (int i = 0; i < ua.Length; i++) faces[i] = (int)ua[i]; }
        }
        if (verts != null && faces != null && verts.Length / 3 > 50 && faces.Length / 3 > 50)
        {
            string fn = Path.Combine(outdir, "mesh_" + idx.ToString("00") + "_v" + (verts.Length / 3) + "_f" + (faces.Length / 3) + ".stl");
            WriteStl(fn, verts, faces);
            Console.WriteLine("  mesh[" + idx + "] verts=" + (verts.Length / 3) + " faces=" + (faces.Length / 3) + " -> " + fn);
            idx++;
        }

        IEnumerable en = obj as IEnumerable;
        if (en != null && !(obj is string))
            foreach (object item in en) Walk(item, outdir, ref idx, seen, depth + 1);
        foreach (FieldInfo f in t.GetFields(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance))
        {
            if (f.FieldType.IsPrimitive || f.FieldType == typeof(string)) continue;
            object v; try { v = f.GetValue(obj); } catch { continue; }
            Walk(v, outdir, ref idx, seen, depth + 1);
        }
    }

    static void WriteStl(string path, float[] v, int[] f)
    {
        using (BinaryWriter bw = new BinaryWriter(File.Create(path)))
        {
            bw.Write(new byte[80]);
            bw.Write((uint)(f.Length / 3));
            for (int i = 0; i < f.Length; i += 3)
            {
                bw.Write(0f); bw.Write(0f); bw.Write(0f);
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
