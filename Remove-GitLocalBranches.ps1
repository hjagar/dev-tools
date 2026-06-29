# Remove-GitLocalBranches.ps1
# Deletes local branches whose remote counterpart no longer exists (merged and deleted on GitHub).

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 1. Limpiar referencias remotas inactivas
git fetch --prune | Out-Null

# 2. Leer ramas protegidas desde .git-tools.json
$repoRoot = (git rev-parse --show-toplevel).Trim()
$configPath = Join-Path $repoRoot '.git-tools.json'
if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
    $protected = $config.protectedBranches
} else {
    $protected = @('develop', 'main')
}

# 3. Obtener la rama actual para protegerla también
$currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()

# 4. Filtrar ramas sin remote (gone)
$candidates = git branch -vv |
    Where-Object { $_ -match ': gone\]' } |
    ForEach-Object {
        $cleanLine = $_.Replace('*', '').Trim()
        ($cleanLine -split '\s+')[0]
    } |
    Where-Object { $_ -notin $protected -and $_ -ne $currentBranch }

if (-not $candidates) {
    [System.Windows.Forms.MessageBox]::Show(
        "Nothing to clean up — all local branches have a remote counterpart.",
        "Git Branch Cleanup",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    exit 0
}

# 5. Mostrar CheckedListBox con todas las ramas pre-seleccionadas
$form = New-Object System.Windows.Forms.Form
$form.Text = "Git Branch Cleanup"
$form.Size = New-Object System.Drawing.Size(420, 380)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Text = "Seleccioná las ramas a eliminar (excluye rama actual '$currentBranch'):"
$label.Location = New-Object System.Drawing.Point(12, 12)
$label.Size = New-Object System.Drawing.Size(380, 34)
$form.Controls.Add($label)

$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = New-Object System.Drawing.Point(12, 52)
$checkedListBox.Size = New-Object System.Drawing.Size(380, 240)
$checkedListBox.CheckOnClick = $true
foreach ($branch in $candidates) {
    $checkedListBox.Items.Add($branch, $true) | Out-Null
}
$form.Controls.Add($checkedListBox)

$btnOk = New-Object System.Windows.Forms.Button
$btnOk.Text = "Eliminar"
$btnOk.Location = New-Object System.Drawing.Point(220, 305)
$btnOk.Size = New-Object System.Drawing.Size(80, 28)
$btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.AcceptButton = $btnOk
$form.Controls.Add($btnOk)

$btnCancel = New-Object System.Windows.Forms.Button
$btnCancel.Text = "Cancelar"
$btnCancel.Location = New-Object System.Drawing.Point(312, 305)
$btnCancel.Size = New-Object System.Drawing.Size(80, 28)
$btnCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.CancelButton = $btnCancel
$form.Controls.Add($btnCancel)

$result = $form.ShowDialog()

if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "Cancelled." -ForegroundColor Gray
    exit 0
}

$selected = $checkedListBox.CheckedItems

if ($selected.Count -eq 0) {
    Write-Host "Nada seleccionado." -ForegroundColor Gray
    exit 0
}

# 6. Borrado
foreach ($branch in $selected) {
    Write-Host "Deleting branch $branch..." -ForegroundColor Red
    git branch -D $branch
}
Write-Host "`nDone." -ForegroundColor Green
