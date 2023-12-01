# Standard Preparation Instructions for a Secure Ubuntu LTS Machine

## Manual Instructions
### Install OpenSSH Server:
During the installation process, you'll have the option to install additional software. Choose to install the OpenSSH server package. If you miss this during the installation, you can install it later using the command:

```bash
sudo apt update
sudo apt install openssh-server
```
### Generate RSA Key Pair on Your Local Machine:
If you haven't generated an RSA key pair on your local machine, you can do so using the following command:

```css
ssh-keygen -t rsa -b 2048
```
This will generate the key pair in the ~/.ssh directory on your local machine.

### Copy Public Key to Server:
After the installation is complete, you need to copy your local machine's public key to the server's authorized_keys file. Run the following command on your local machine:

```javascript
ssh-copy-id -i ~/.ssh/id_rsa <username>@<server_ip>
```
Replace <username> with your created username on the server, and <server_ip> with the server's IP address.

### Configure SSH Server:
Edit the SSH server configuration file on the server:

```bash
sudo nano /etc/ssh/sshd_config
```
Make sure the following settings are set correctly:

```yaml
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
```

Check the lower SSH_Config directories to makes sure PasswordAuthentication is disabled:
```bash
cd /etc/ssh/sshd_config.d/
sudo nano <config_file_name>
```

Save the changes and restart the SSH service:

```bash
sudo service ssh restart
```
### Test RSA Key Authentication:
Try logging in to the server using your RSA key:

```javascript
ssh -i ~/.ssh/id_rsa <username>@<server_ip>
```
If everything is set up correctly, you should be able to log in without using a password.

### Disable Root Login:
For better security, you might want to disable direct root login via SSH. Edit the SSH configuration file again and change:

```perl
PermitRootLogin no
```
Save the changes and restart the SSH service.

```bash
sudo service ssh restart
```