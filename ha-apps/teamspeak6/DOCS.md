# TeamSpeak 6 Server — Documentation

## Quick Start

1. Set **Accept TeamSpeak License** to `true` (required!)
2. Optionally set a **Server Password** and **Server Name**
3. Click **Start**
4. Check the **Log** tab for the first-time admin **privilege key (token)**
5. Connect with your TeamSpeak 6 client to `<your-ha-ip>:9987`

## Finding the Privilege Key

On first start, look in the log for a line like:

```
token=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

In your TeamSpeak client: **Permissions → Use Privilege Key** → paste the token.

## Port Forwarding (External Access)

To allow friends outside your local network to connect, forward these ports on your router:

| Port | Protocol |
|---|---|
| 9987 | UDP |
| 30033 | TCP |

The Query ports (10011, 10022, 10080) should **not** be publicly exposed unless needed.

## Changing Ports

Go to the **Configuration** tab and adjust port numbers.  
Then go to the **Network** tab and update the host port mappings to match.

## Backup

The add-on stores all data in a persistent `/data/teamspeak6` folder.  
This is automatically included in Home Assistant backups.
