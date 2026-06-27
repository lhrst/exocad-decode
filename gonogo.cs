using System;
using System.Runtime.InteropServices;
class G {
  [DllImport("kernel32", SetLastError=true, CharSet=CharSet.Unicode)] static extern IntPtr LoadLibrary(string p);
  [DllImport("kernel32", SetLastError=true)] static extern IntPtr GetProcAddress(IntPtr h, string n);
  static void Main() {
    Console.WriteLine("loading de-netified DBN_native.dll (pure native)...");
    IntPtr h = LoadLibrary(@"C:\work\DBN_native.dll");
    if (h == IntPtr.Zero) { Console.WriteLine("LoadLibrary FAILED err=" + Marshal.GetLastWin32Error()); return; }
    Console.WriteLine("LoadLibrary OK handle=0x" + h.ToString("x") + " (NO native-init crash!)");
    IntPtr p = GetProcAddress(h, "?Deserialize@CMesh@DentalBase@@UEAA?AW4RetVal@2@AEAVISerializationInfo@2@PEAVISerializationObject@2@@Z");
    Console.WriteLine("CMesh::Deserialize addr=0x" + p.ToString("x"));
    Console.WriteLine("GONOGO_GREEN");
  }
}
