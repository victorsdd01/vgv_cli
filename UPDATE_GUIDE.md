# 🔄 VGV CLI - Update Guide

## 📋 How Version Updates Work

When you install VGV CLI, you get the latest version from the main branch. To get updates when new versions are released, you need to manually update your installation.

## 🔍 Check Current Version

### **Method 1: Direct Command (Recommended)**
```bash
dart run bin/vgv.dart --version
```

### **Method 2: Check Installed Package**
```bash
dart pub global list | grep vgv
```

### **Method 3: From Repository**
```bash
cd vgv_cli
git log --oneline -1
```

## 🚀 Update to Latest Version

### **Option 1: Update from Git (Recommended)**
```bash
# Update to latest version from main branch
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git

# Update to specific version (when tags are available)
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git --git-ref v1.1.0
```

### **Option 2: Update from Local Repository**
```bash
# If you have the repository cloned locally
cd vgv_cli
git pull origin main
dart pub global activate --source path .
```

### **Option 3: Use Update Scripts**

#### **Windows:**
```cmd
# Using batch script
update.bat

# Using PowerShell script
powershell -ExecutionPolicy Bypass -File update.ps1
```

#### **macOS/Linux:**
```bash
# Using shell script
./update.sh
```

## 📦 Version Management

### **Available Versions**
- **Main Branch**: Latest development version
- **Release Tags**: Stable versions (when available)
- **Specific Commits**: Any commit hash

### **Update to Specific Version**
```bash
# Update to a specific commit
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git --git-ref abc1234

# Update to a specific branch
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git --git-ref feature/new-feature
```

## 🔧 Troubleshooting Updates

### **Common Issues**

#### **"Command not found" after update**
```bash
# Reinstall the CLI
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git

# Check PATH configuration
echo $PATH | grep .pub-cache
```

#### **Version not updating**
```bash
# Force reinstall
dart pub global deactivate vgv
dart pub global activate --source git https://github.com/victorsdd01/vgv_cli.git

# Clear cache (if needed)
dart pub cache clean
```

#### **Permission issues**
```bash
# On macOS/Linux
sudo chmod +x update.sh
./update.sh

# On Windows (PowerShell as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### **Verify Update Success**
```bash
# Check version
dart run bin/vgv.dart --version

# Test functionality
vgv --help
```

## 📋 Update Checklist

### **Before Updating:**
- [ ] Check current version
- [ ] Review changelog for breaking changes
- [ ] Backup any custom configurations

### **After Updating:**
- [ ] Verify new version is installed
- [ ] Test basic functionality
- [ ] Check for new features
- [ ] Update any custom scripts

## 🔄 Automatic Updates (Future Feature)

In future versions, we plan to add:
- **Auto-update notifications**
- **One-click update commands**
- **Update checking on startup**
- **Rollback functionality**

## 📚 Version History

### **v1.0.0** (Current)
- Initial release
- Interactive project creation
- Clean Architecture support
- BLoC, Cubit, Provider state management
- Freezed code generation
- Go Router integration
- Internationalization
- Multi-platform support
- Cross-platform installation scripts

### **Upcoming Features**
- Non-interactive mode
- Template customization
- Plugin system
- Advanced configuration options

## 🎯 Best Practices

### **Regular Updates**
- Update monthly for latest features
- Update before starting new projects
- Check for security updates

### **Version Control**
- Keep track of which version you're using
- Test updates in a development environment
- Have a rollback plan

### **Community**
- Report issues on GitHub
- Share feedback and suggestions
- Contribute to the project

---

**Keep your VGV CLI updated for the best experience! 🚀** 