// NOTES:
// Write your first driver: https://docs.microsoft.com/en-us/windows-hardware/drivers/gettingstarted/writing-a-very-small-kmdf--driver
// 
// I installed the Windows Driver Kit (WDK) from: https://docs.microsoft.com/en-us/windows-hardware/drivers/download-the-wdk
//     - This downloaded "wdksetup.exe"
//     - This gave an option to install to this computer, or download for installing on seperate computer, I chose the later
//     - With the "download for installation on separate computer", it just downloads the installers to the specified location
//     - Running the installers will install parts of the WDK, when I did this they were installed to:
//          C:\Program Files (x86)\Windows Kits\10
//     - I ran "Windows Driver Kit-x86_en-us.msi"
//         - This seemed to install "devcon.exe" (used to install drivers) to C:\Program Files (x86)\Windows Kits\10\Tools\x64
//     - I ran "Windows Driver Kit Headers and Libs-x86_en-us.msi"
//         - This seemed to install the ntoskrnl.lib file I needed to C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22000.0\km\x64
//         - There was an installer for the arm architectures as well




const std = @import("std");

const win32 = struct {
    usingnamespace @import("win32").foundation;
    usingnamespace @import("win32").system.kernel;
};

pub extern "ntoskrnl" fn DbgPrint(format: [*:0]const u8, ...) callconv(std.os.windows.WINAPI) u32;

export fn DriverEntry(driver_obj: *c_void, registry_path: win32.UNICODE_STRING) callconv(std.os.windows.WINAPI) win32.NTSTATUS {
    _ = driver_obj;
    _ = registry_path;
    _ = DbgPrint("WindowsMidiDriver: DriverEntry\n");

    // TODO: register EvtDeviceAdd callback??

    return 0;
}
