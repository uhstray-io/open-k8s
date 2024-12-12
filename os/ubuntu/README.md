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

```bash
ssh-keygen -t ed25519
```
This will generate the key pair in the ~/.ssh directory on your local machine.

### Copy Private Key to Server:
After the installation is complete, you need to copy your local machine's public key to the server's authorized_keys file. Run the following command on your local machine:

```bash
ssh-copy-id -i ~/.ssh/id_rsa <username>@<server_ip>
```

Copy an SSH Key to your server after you've locked down the server to only allow key-based authentication.

```bash
ssh-copy-id -i ~/.ssh/id_rsa -o 'IdentityFile ~/.ssh/<your-already-existing-id>' <username>@<server_ip>
```

Replace <username> with your created username on the server, and <server_ip> with the server's IP address.

### Configure SSH Server:
Edit the SSH server configuration file on the server:

```bash
sudo nano /etc/ssh/sshd_config
```
Make sure the following settings are set correctly:

```perl
PubkeyAuthentication yes
PasswordAuthentication no
ChallengeResponseAuthentication no
```

Check the lower SSH_Config directories to makes sure PasswordAuthentication is disabled:
```bash
cd /etc/ssh/sshd_config.d/
sudo nano <config_file_name>

or 

sudo nano /etc/ssh/sshd_config.d/<config_file_name>
```

Save the changes and restart the SSH service:

```bash
sudo service ssh restart
```
### Test RSA Key Authentication:
Try logging in to the server using your RSA key:

```bash
ssh -i ~/.ssh/id_rsa <username>@<server_ip>
```
If everything is set up correctly, you should be able to log in without using a password.

### Disallow external traffic to access SSH port:

Assign the `LOCAL_NETWORK` variable to your local network IP range. This will allow only local network traffic to access the SSH port.

```bash
LOCAL_NETWORK="192.168.1.0/24"

sudo ufw allow from $LOCAL_NETWORK proto tcp to any port 22  # SSH
```

### Disable Root Login:
For better security, you might want to disable direct root login via SSH. Edit the SSH configuration file again and change:

```perl
PermitRootLogin no
```
Save the changes and restart the SSH service.

```bash
sudo service ssh restart
```
