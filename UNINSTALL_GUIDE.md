# 🗑️ VGV CLI - Uninstall Guide

## 📋 Why Uninstall?

There are several reasons why you might want to uninstall VGV CLI:

- **No longer needed** - You've finished your Flutter project
- **Trying a different tool** - Switching to another CLI tool
- **Troubleshooting** - Clean reinstall to fix issues
- **System cleanup** - Removing unused tools
- **Version conflicts** - Resolving dependency issues

## 🔍 Check Installation Status

### **Verify CLI is Installed:**
```bash
# Check if CLI is available
vgv --version

# Or check installed packages
dart pub global list | grep vgv

# Check installation location
which vgv
```

## 🚀 Uninstall Methods

### **Method 1: Using Uninstall Scripts (Recommended)**

#### **Windows:**
```cmd
# Using batch script
uninstall.bat

# Using PowerShell script
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

#### **macOS/Linux:**
```bash
# Using shell script
./uninstall.sh
```

### **Method 2: Manual Uninstall**

#### **Step 1: Deactivate Package**
```bash
dart pub global deactivate vgv
```

#### **Step 2: Remove from PATH (if needed)**

**macOS/Linux:**
```bash
# Check if PATH contains pub-cache
echo $PATH | grep .pub-cache

# Remove from shell config files
# For Bash
sed -i '/export PATH.*\.pub-cache\/bin/d' ~/.bashrc

# For Zsh
sed -i '' '/export PATH.*\.pub-cache\/bin/d' ~/.zshrc

# For Fish
sed -i '/set -gx PATH.*\.pub-cache\/bin/d' ~/.config/fish/config.fish
```

**Windows:**
```cmd
# Check if PATH contains pub-cache
echo %PATH% | findstr .pub-cache

# Remove manually from System Properties > Environment Variables
# Or use PowerShell
[Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
```

#### **Step 3: Clean Cache (Optional)**
```bash
# Clear Dart cache
dart pub cache clean

# Remove pub-cache directory (be careful!)
rm -rf ~/.pub-cache
```

## 🔧 Platform-Specific Instructions

### **Windows**

#### **Command Prompt:**
```cmd
# Deactivate package
dart pub global deactivate vgv

# Check if removed
vgv --version
```

#### **PowerShell:**
```powershell
# Deactivate package
dart pub global deactivate vgv

# Remove from PATH
$pubCacheBin = "$env:USERPROFILE\.pub-cache\bin"
$newPath = ($env:PATH -split ';' | Where-Object { $_ -ne $pubCacheBin }) -join ';'
[Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
```

### **macOS**

#### **Terminal:**
```bash
# Deactivate package
dart pub global deactivate vgv

# Remove from shell config
if [[ "$SHELL" == *"zsh"* ]]; then
    sed -i '' '/export PATH.*\.pub-cache\/bin/d' ~/.zshrc
elif [[ "$SHELL" == *"bash"* ]]; then
    sed -i '/export PATH.*\.pub-cache\/bin/d' ~/.bashrc
fi

# Reload shell config
source ~/.zshrc  # or ~/.bashrc
```

### **Linux**

#### **Bash/Zsh:**
```bash
# Deactivate package
dart pub global deactivate vgv

# Remove from shell config
if [[ "$SHELL" == *"zsh"* ]]; then
    sed -i '/export PATH.*\.pub-cache\/bin/d' ~/.zshrc
elif [[ "$SHELL" == *"bash"* ]]; then
    sed -i '/export PATH.*\.pub-cache\/bin/d' ~/.bashrc
fi

# Reload shell config
source ~/.zshrc  # or ~/.bashrc
```

#### **Fish Shell:**
```fish
# Deactivate package
dart pub global deactivate vgv

# Remove from fish config
sed -i '/set -gx PATH.*\.pub-cache\/bin/d' ~/.config/fish/config.fish

# Reload fish config
source ~/.config/fish/config.fish
```

## ✅ Verify Uninstall

### **Check CLI Availability:**
```bash
# Should show "command not found"
vgv --version

# Check if package is still listed
dart pub global list | grep vgv

# Check PATH
echo $PATH | grep .pub-cache
```

### **Expected Results:**
- ❌ `vgv: command not found`
- ❌ No vgv in `dart pub global list`
- ❌ No .pub-cache in PATH

## 🔄 Reinstall After Uninstall

### **Clean Reinstall:**
```bash
# Install fresh copy
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git

# Verify installation
vgv --version
```

### **From Local Source:**
```bash
# Clone repository
git clone https://github.com/victorsdd01/vgv_cli.git
cd vgv_cli

# Install from local source
dart pub global activate --source path .

# Verify installation
vgv --version
```

## 🛠️ Troubleshooting

### **Common Issues**

#### **"Command not found" but package still listed**
```bash
# Force remove from global packages
dart pub global deactivate vgv --force

# Clear cache
dart pub cache clean
```

#### **PATH still contains pub-cache**
```bash
# Check all shell config files
grep -r "pub-cache" ~/.bashrc ~/.zshrc ~/.config/fish/config.fish

# Remove manually from each file
```

#### **Permission denied errors**
```bash
# Use sudo for system-wide removal
sudo dart pub global deactivate vgv

# Or fix permissions
chmod +x uninstall.sh
```

### **Complete Cleanup**
```bash
# Nuclear option - remove everything
dart pub global deactivate vgv
rm -rf ~/.pub-cache
rm -rf ~/.dart
rm -rf ~/.pub

# Reinstall Dart/Flutter if needed
```

## 📋 Uninstall Checklist

### **Before Uninstalling:**
- [ ] Backup any custom configurations
- [ ] Note down current version
- [ ] Save any custom templates
- [ ] Export any project configurations

### **During Uninstall:**
- [ ] Deactivate the package
- [ ] Remove from PATH
- [ ] Clean shell config files
- [ ] Clear cache (optional)

### **After Uninstall:**
- [ ] Verify CLI is removed
- [ ] Check PATH is clean
- [ ] Test system functionality
- [ ] Remove any remaining files

## 🎯 Best Practices

### **Safe Uninstall:**
- Always use uninstall scripts when available
- Backup configurations before removing
- Test system after uninstall
- Keep reinstall instructions handy

### **Complete Removal:**
- Remove from all shell configs
- Clean all caches
- Remove from PATH
- Verify complete removal

### **Reinstall Preparation:**
- Note down any custom settings
- Save any modified templates
- Keep installation commands ready
- Test reinstall process

---

**Uninstall completed successfully! 🎉** 