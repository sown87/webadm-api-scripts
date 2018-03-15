# webadm-api-scripts
Scripts for interfacing with RCDevs WebADM API Manager via cli.  These are written in perl and use the excellent mojolicious Mojo::UserAgent and Mojo::JSON modules for the JSON-RPC transactions.

Descriptions:
* **get-user-qr.pl** - Takes common name CN of user in WebADM LDAP or AD database, retrieves QR code for user (if user and QR code exist), and sends GIF image file attachment via SMTP email.  Uses perl modules for all tasks.  For internal SMTP only-- NOT RECOMMENDED if you send over the Internet unless you can control security of all mail relays. Use of script requires editing initial variables at beginning.


