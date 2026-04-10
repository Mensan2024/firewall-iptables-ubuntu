Ce projet consiste à mettre en place un firewall Linux complet sous Ubuntu 22.04 en utilisant `iptables`.
Le serveur agit comme une passerelle sécurisée (gateway) entre un réseau local (LAN) et Internet (WAN).
Objectifs du projet :
- Sécuriser un réseau local avec une politique restrictive
- Filtrer et contrôler le trafic entrant, sortant et transféré
- Mettre en place le **routage IP (IP Forwarding)**
- Configurer le **NAT (Masquerade)** pour l’accès Internet
- Assurer la **persistance des règles firewall**
- Journaliser les paquets bloqués

⚙️ Technologies utilisées

| Technologie         | Rôle |
|--------------------|------|
| Ubuntu 22.04       | Système d’exploitation |
| iptables           | Firewall / filtrage réseau |
| Netplan            | Configuration réseau |
| iptables-persistent| Sauvegarde des règles |
| VMware             | Virtualisation |

🔐 Configuration du firewall

1. Politique par défaut (sécurité maximale)
```bash
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP
````
2. Loopback (nécessaire au système)

```bash
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
```
3. Connexions établies
```bash
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```
4. Accès LAN (réseau interne)

```bash
iptables -A INPUT -i ens37 -j ACCEPT
iptables -A OUTPUT -o ens37 -j ACCEPT
```
5. DNS (résolution de noms)

```bash
iptables -A OUTPUT -p udp --dport 53 -o ens33 -j ACCEPT
```
6. ICMP (tests réseau)

```bash
iptables -A INPUT -p icmp -j ACCEPT
iptables -A OUTPUT -p icmp -j ACCEPT
```
7. Accès Internet du firewall

```bash
iptables -A OUTPUT -o ens33 -j ACCEPT
```
8. Autorisation du forwarding LAN → WAN

```bash
iptables -A FORWARD -i ens37 -o ens33 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
```
9. NAT (Masquerade)

```bash
iptables -t nat -A POSTROUTING -s 192.168.1.0/24 -o ens33 -j MASQUERADE
```
10. Journalisation des paquets rejetés

```bash
iptables -A INPUT -j LOG --log-prefix "FIREWALL_DROP: "
```
11.Tests réalisés

| Test                     | Résultat attendu  | Statut |
| ------------------------ | ----------------- | ------ |
| Ping firewall depuis LAN | OK                | ✅      |
| Accès Internet (8.8.8.8) | OK via NAT        | ✅      |
| Navigation web           | OK                | ✅      |
| Scan Nmap                | Ports filtrés     | ✅      |
| Redémarrage système      | Règles conservées | ✅      |

📁 Structure du projet

```
firewall-iptables-ubuntu/
├── firewall-iptables-report.pdf
├── tp-firewall-iptables-report.pdf
└── README.md
 🚀 Compétences acquises

* Administration Linux avancée
* Sécurité réseau avec iptables
* Routage IP et NAT
* Filtrage de paquets
* Configuration réseau (Netplan)
* Virtualisation (VMware)
* Débogage réseau
* Documentation technique professionnelle

👤 Auteur
Codjia Mensan Moréno
🔗 GitHub : [https://github.com/Mensan2024](https://github.com/Mensan2024)
📜 Licence
Ce projet est sous licence MIT – libre d’utilisation.

