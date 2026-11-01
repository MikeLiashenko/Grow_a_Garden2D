param([Parameter(Mandatory=$true)][string]$Exe, [string]$Args_ = "", [int]$Timeout = 70, [string]$OutDir = $env:TEMP)
# Starts a program on a separate, never-shown Windows desktop and waits for it.
# Environment variables (GG_TOUR) are inherited. Stdout and stderr go to OutDir.
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class HiddenDesktop {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct STARTUPINFO { public int cb; public string lpReserved; public string lpDesktop; public string lpTitle; public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags; public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError; }
  [StructLayout(LayoutKind.Sequential)]
  public struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
  [StructLayout(LayoutKind.Sequential)]
  public struct SECURITY_ATTRIBUTES { public int nLength; public IntPtr lpSecurityDescriptor; public bool bInheritHandle; }
  [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern IntPtr CreateDesktop(string name, IntPtr device, IntPtr devmode, int flags, uint access, IntPtr sa);
  [DllImport("user32.dll", SetLastError=true)] public static extern bool CloseDesktop(IntPtr h);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern bool CreateProcess(string app, string cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string cwd, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
  public static extern IntPtr CreateFile(string name, uint access, uint share, ref SECURITY_ATTRIBUTES sa, uint disp, uint attrs, IntPtr tmpl);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern uint WaitForSingleObject(IntPtr h, uint ms);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool GetExitCodeProcess(IntPtr h, out uint code);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool TerminateProcess(IntPtr h, uint code);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
  public static int Run(string exe, string args, string cwd, string outPath, string errPath, int timeoutMs) {
    string name = "GGHidden" + Guid.NewGuid().ToString("N").Substring(0, 8);
    IntPtr desk = CreateDesktop(name, IntPtr.Zero, IntPtr.Zero, 0, 0x10000000, IntPtr.Zero);
    if (desk == IntPtr.Zero) throw new Exception("CreateDesktop failed: " + Marshal.GetLastWin32Error());
    var sa = new SECURITY_ATTRIBUTES { nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)), bInheritHandle = true };
    IntPtr o = CreateFile(outPath, 0x40000000, 3, ref sa, 2, 0x80, IntPtr.Zero);
    IntPtr e = CreateFile(errPath, 0x40000000, 3, ref sa, 2, 0x80, IntPtr.Zero);
    var si = new STARTUPINFO { cb = Marshal.SizeOf(typeof(STARTUPINFO)), lpDesktop = name, dwFlags = 0x100, hStdOutput = o, hStdError = e };
    PROCESS_INFORMATION pi;
    bool ok = CreateProcess(exe, "\"" + exe + "\" " + args, IntPtr.Zero, IntPtr.Zero, true, 0x08000000, IntPtr.Zero, cwd, ref si, out pi);
    int err = Marshal.GetLastWin32Error();
    CloseHandle(o); CloseHandle(e);
    if (!ok) { CloseDesktop(desk); throw new Exception("CreateProcess failed: " + err); }
    int result;
    if (WaitForSingleObject(pi.hProcess, (uint)timeoutMs) != 0) { TerminateProcess(pi.hProcess, 1); WaitForSingleObject(pi.hProcess, 5000); result = -1; }
    else { uint code; GetExitCodeProcess(pi.hProcess, out code); result = (int)code; }
    CloseHandle(pi.hProcess); CloseHandle(pi.hThread); CloseDesktop(desk);
    return result;
  }
}
"@
$cwd = "C:\Work\Games\Grow a Garden 2D"
$code = [HiddenDesktop]::Run($Exe, $Args_, $cwd, "$OutDir\hidden_out.log", "$OutDir\hidden_err.log", $Timeout * 1000)
if ($code -eq -1) { "TIMEOUT - killed" } else { "exit code $code" }
