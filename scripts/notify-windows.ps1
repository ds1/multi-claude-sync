# Windows System Notification for Claude Code
# Usage: powershell -ExecutionPolicy Bypass -File notify-windows.ps1 -Title "..." -Details "..." [-ActionType "migration|config|decision"]
#
# This script displays a topmost modal dialog for actions requiring user attention.
# Returns JSON with the user's response: {"Action":"acknowledged|completed|dismissed", "Response":"...", "Screenshot":"..."}
#
# To customize for your use case, modify the $titleLabel.Text and $detailsBox.Text values below,
# or pass parameters when calling the script.

param(
    [string]$Title = "ACTION: User action required",
    [string]$Details = "Details of the action required...",
    [string]$ActionType = "general"
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Claude Code - Action Required"
$form.Size = New-Object System.Drawing.Size(600, 750)
$form.StartPosition = "CenterScreen"
$form.TopMost = $true
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(250, 250, 250)
$form.KeyPreview = $true

$script:screenshotPath = ""

# Function to attach screenshot from clipboard
function AttachScreenshot {
    param($statusLabel)
    if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
        $img = [System.Windows.Forms.Clipboard]::GetImage()
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $script:screenshotPath = "$env:TEMP\claude_screenshot_$timestamp.png"
        $img.Save($script:screenshotPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $statusLabel.Text = "Screenshot attached (Ctrl+V)"
        $statusLabel.ForeColor = [System.Drawing.Color]::Green
        return $true
    }
    return $false
}

# Title
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$titleLabel.Size = New-Object System.Drawing.Size(550, 25)
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$titleLabel.Text = $Title
$form.Controls.Add($titleLabel)

# Details panel - taller to fit all content
$detailsBox = New-Object System.Windows.Forms.TextBox
$detailsBox.Location = New-Object System.Drawing.Point(20, 50)
$detailsBox.Size = New-Object System.Drawing.Size(545, 250)
$detailsBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$detailsBox.Multiline = $true
$detailsBox.ReadOnly = $true
$detailsBox.ScrollBars = "Vertical"
$detailsBox.BackColor = [System.Drawing.Color]::White
$detailsBox.BorderStyle = "FixedSingle"
$detailsBox.Text = $Details
$form.Controls.Add($detailsBox)

# Response section
$responseLabel = New-Object System.Windows.Forms.Label
$responseLabel.Location = New-Object System.Drawing.Point(20, 310)
$responseLabel.Size = New-Object System.Drawing.Size(545, 20)
$responseLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$responseLabel.Text = "Your response (Enter to quick-acknowledge, Shift+Enter for newline):"
$form.Controls.Add($responseLabel)

$responseBox = New-Object System.Windows.Forms.TextBox
$responseBox.Location = New-Object System.Drawing.Point(20, 335)
$responseBox.Size = New-Object System.Drawing.Size(545, 60)
$responseBox.Multiline = $true
$responseBox.ScrollBars = "Vertical"
$responseBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$responseBox.AcceptsReturn = $false
$form.Controls.Add($responseBox)

# Screenshot section
$screenshotLabel = New-Object System.Windows.Forms.Label
$screenshotLabel.Location = New-Object System.Drawing.Point(20, 405)
$screenshotLabel.Size = New-Object System.Drawing.Size(545, 20)
$screenshotLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$screenshotLabel.Text = "Screenshot: Press Ctrl+V to paste from clipboard, or click Attach"
$form.Controls.Add($screenshotLabel)

$screenshotStatus = New-Object System.Windows.Forms.Label
$screenshotStatus.Location = New-Object System.Drawing.Point(20, 430)
$screenshotStatus.Size = New-Object System.Drawing.Size(400, 25)
$screenshotStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$screenshotStatus.ForeColor = [System.Drawing.Color]::Gray
$screenshotStatus.Text = "No screenshot attached"
$form.Controls.Add($screenshotStatus)

$attachButton = New-Object System.Windows.Forms.Button
$attachButton.Location = New-Object System.Drawing.Point(430, 425)
$attachButton.Size = New-Object System.Drawing.Size(135, 30)
$attachButton.Text = "Attach Screenshot"
$attachButton.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$attachButton.Add_Click({
    if (AttachScreenshot $screenshotStatus) {
        # Success handled in function
    } else {
        $screenshotStatus.Text = "No image in clipboard"
        $screenshotStatus.ForeColor = [System.Drawing.Color]::Red
    }
})
$form.Controls.Add($attachButton)

# Handle Ctrl+V at form level for screenshots
$form.Add_KeyDown({
    param($sender, $e)
    if ($e.Control -and $e.KeyCode -eq 'V') {
        if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
            AttachScreenshot $screenshotStatus
            $e.Handled = $true
            $e.SuppressKeyPress = $true
        }
    }
})

# Handle Enter in response box to quick-acknowledge
$responseBox.Add_KeyDown({
    param($sender, $e)
    if ($e.KeyCode -eq 'Return' -and -not $e.Shift) {
        $script:result.Action = "acknowledged"
        $script:result.Response = $responseBox.Text
        $script:result.Screenshot = $script:screenshotPath
        $form.Close()
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
})

# Button explanations
$buttonHelpLabel = New-Object System.Windows.Forms.Label
$buttonHelpLabel.Location = New-Object System.Drawing.Point(20, 470)
$buttonHelpLabel.Size = New-Object System.Drawing.Size(545, 70)
$buttonHelpLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$buttonHelpLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$buttonHelpLabel.Text = @"
ACKNOWLEDGE - I've seen this, will do it later (task stays pending)
COMPLETED - I've done the steps above (task marked done, syncs updated)
DISMISS - Close without responding (you may miss this action)
"@
$form.Controls.Add($buttonHelpLabel)

# Result variable
$script:result = @{ Action = ""; Response = ""; Screenshot = "" }

# Acknowledge button
$ackButton = New-Object System.Windows.Forms.Button
$ackButton.Location = New-Object System.Drawing.Point(20, 650)
$ackButton.Size = New-Object System.Drawing.Size(160, 45)
$ackButton.Text = "Acknowledge"
$ackButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$ackButton.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
$ackButton.FlatStyle = "Flat"
$ackButton.Add_Click({
    $script:result.Action = "acknowledged"
    $script:result.Response = $responseBox.Text
    $script:result.Screenshot = $script:screenshotPath
    $form.Close()
})
$form.Controls.Add($ackButton)

# Completed button
$completeButton = New-Object System.Windows.Forms.Button
$completeButton.Location = New-Object System.Drawing.Point(210, 650)
$completeButton.Size = New-Object System.Drawing.Size(160, 45)
$completeButton.Text = "Completed"
$completeButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$completeButton.BackColor = [System.Drawing.Color]::FromArgb(76, 175, 80)
$completeButton.ForeColor = [System.Drawing.Color]::White
$completeButton.FlatStyle = "Flat"
$completeButton.Add_Click({
    $script:result.Action = "completed"
    $script:result.Response = $responseBox.Text
    $script:result.Screenshot = $script:screenshotPath
    $form.Close()
})
$form.Controls.Add($completeButton)

# Dismiss button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(405, 650)
$cancelButton.Size = New-Object System.Drawing.Size(160, 45)
$cancelButton.Text = "Dismiss"
$cancelButton.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$cancelButton.BackColor = [System.Drawing.Color]::FromArgb(230, 230, 230)
$cancelButton.FlatStyle = "Flat"
$cancelButton.Add_Click({
    $script:result.Action = "dismissed"
    $script:result.Response = $responseBox.Text
    $script:result.Screenshot = $script:screenshotPath
    $form.Close()
})
$form.Controls.Add($cancelButton)

# Show form
$form.ShowDialog() | Out-Null

# Output result as JSON for Claude to parse
$script:result | ConvertTo-Json -Compress
