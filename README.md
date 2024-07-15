# PowerShell Batch Add Firewall Rules
This is a powershell script that allows you to select a path and add a firewall rule for every executable inside the directory aswell as the subdirectorys with the click of a button.
## What does it do?
This script gets every executable inside a given directory aswell as its sub directories and blocks inbound or/and outbound network traffic for these executables by creating individual firewall rules inside the Windows Defender Firewall with Advanced Security.
## Why use this?
Creating firewall rules manually for each executable in a directory, especially when dealing with multiple executables and subdirectories, is a time-consuming and tedious task. 

This PowerShell script automates the process, saving you significant time and effort. 
## How do i use this?
Just download the .ps1 file from this repository and run it with administrative privileges. 
If you launch it without administrative privileges, it will open a new powershell with the required privileges.

When you execute the script, you will be greeted with a GUI.
- **Choose Path Button:** Simply click the "Choose Path" button. This opens a Windows File Explorer window, allowing you to navigate and select the desired directory. This directory is where the script will search for executable files to create firewall rules for.

- **Path Label:** Once you've selected a directory, the path will be displayed inside the GUI. If you want to double-check the contents of the selected folder, just double-click the path label, and it will open the directory in Windows File Explorer for you to review.

- **Block Outbound Traffic Button:** Click this button to block all outbound network traffic for every executable in the selected directory and its subdirectories. This action creates individual firewall rules for each executable within the Windows Defender Firewall with Advanced Security.

- **Block Inbound Traffic Button:** Click this button to block all inbound network traffic for every executable in the selected directory and its subdirectories. Like the outbound button, this also creates individual firewall rules for each executable within the Windows Defender Firewall with Advanced Security.
