#!/bin/bash

################################################################################
# Script : firewall.sh
# Projet : Firewall iptables sous Ubuntu 22.04
# Auteur : Mensan2024
# Description : Configuration automatisée d'un firewall avec routage et NAT
#              Politique DROP par défaut
################################################################################

# 🎨 Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 📋 Variables (à MODIFIER selon ta configuration)
LAN_INTERFACE="ens37"
WAN_INTERFACE="ens33"
LAN_NETWORK="192.168.1.0/24"
FIREWALL_LAN_IP="192.168.1.1"

################################################################################
# FONCTIONS
################################################################################

# Afficher une ligne de séparation
print_separator() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# Afficher un message de succès
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Afficher un message d'information
print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# Afficher un message d'avertissement
print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# Afficher un message d'erreur
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Vérifier que le script est exécuté en root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Ce script doit être exécuté en tant que root (sudo)"
        echo "Utilise : sudo ./firewall.sh"
        exit 1
    fi
}

# Vérifier que les interfaces existent
check_interfaces() {
    print_info "Vérification des interfaces réseau..."
    
    if ! ip link show "$LAN_INTERFACE" &> /dev/null; then
        print_error "Interface $LAN_INTERFACE introuvable"
        print_info "Interfaces disponibles :"
        ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print "  - " $2}'
        exit 1
    fi
    
    if ! ip link show "$WAN_INTERFACE" &> /dev/null; then
        print_error "Interface $WAN_INTERFACE introuvable"
        exit 1
    fi
    
    print_success "Interfaces vérifiées : LAN=$LAN_INTERFACE | WAN=$WAN_INTERFACE"
}

# Sauvegarder les règles actuelles
backup_current_rules() {
    local backup_file="/etc/iptables/rules.v4.backup.$(date +%Y%m%d_%H%M%S)"
    if [[ -f /etc/iptables/rules.v4 ]]; then
        cp /etc/iptables/rules.v4 "$backup_file"
        print_success "Sauvegarde des règles existantes : $backup_file"
    else
        print_info "Aucune règle existante à sauvegarder"
    fi
}

# Réinitialiser complètement les règles
flush_rules() {
    print_info "Réinitialisation des règles iptables..."
    
    # Vider toutes les règles
    iptables -F
    iptables -t nat -F
    iptables -t mangle -F
    
    # Supprimer les chaînes personnalisées
    iptables -X
    iptables -t nat -X
    iptables -t mangle -X
    
    print_success "Règles réinitialisées"
}

# Définir les politiques par défaut (DROP)
set_default_policies() {
    print_info "Application des politiques DROP par défaut..."
    
    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP
    
    print_success "Politiques DROP appliquées"
}

# Configurer la boucle locale (loopback)
configure_loopback() {
    print_info "Configuration de la boucle locale (lo)..."
    
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    print_success "Loopback configuré"
}

# Autoriser les connexions établies et associées
configure_conntrack() {
    print_info "Autorisation des connexions établies et associées..."
    
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    print_success "Conntrack configuré"
}

# Configurer l'accès au réseau local (LAN)
configure_lan_access() {
    print_info "Configuration de l'accès au réseau local ($LAN_INTERFACE)..."
    
    iptables -A INPUT -i "$LAN_INTERFACE" -j ACCEPT
    iptables -A OUTPUT -o "$LAN_INTERFACE" -j ACCEPT
    
    print_success "Accès LAN autorisé"
}

# Configurer le DNS
configure_dns() {
    print_info "Configuration du DNS (port 53)..."
    
    iptables -A OUTPUT -p udp --dport 53 -o "$WAN_INTERFACE" -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 53 -o "$WAN_INTERFACE" -j ACCEPT
    
    print_success "DNS autorisé"
}

# Configurer ICMP (ping)
configure_icmp() {
    print_info "Configuration ICMP (ping)..."
    
    iptables -A INPUT -p icmp -j ACCEPT
    iptables -A OUTPUT -p icmp -j ACCEPT
    iptables -A FORWARD -p icmp -j ACCEPT
    
    print_success "ICMP autorisé"
}

# Autoriser l'accès Internet depuis le firewall
configure_firewall_internet() {
    print_info "Autorisation de l'accès Internet pour le firewall..."
    
    iptables -A OUTPUT -o "$WAN_INTERFACE" -j ACCEPT
    
    print_success "Accès Internet autorisé pour le firewall"
}

# Configurer le transfert LAN -> WAN
configure_forwarding() {
    print_info "Configuration du transfert LAN → WAN..."
    
    iptables -A FORWARD -i "$LAN_INTERFACE" -o "$WAN_INTERFACE" -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
    
    print_success "Transfert LAN → WAN configuré"
}

# Configurer NAT (MASQUERADE)
configure_nat() {
    print_info "Configuration du NAT (MASQUERADE) pour $LAN_NETWORK..."
    
    iptables -t nat -A POSTROUTING -s "$LAN_NETWORK" -o "$WAN_INTERFACE" -j MASQUERADE
    
    print_success "NAT configuré"
}

# Configurer la journalisation (logging)
configure_logging() {
    print_info "Configuration de la journalisation des paquets bloqués..."
    
    # Limiter le nombre de logs pour éviter le spam
    iptables -A INPUT -j LOG --log-prefix "DROP_INPUT: " --log-level 4
    iptables -A FORWARD -j LOG --log-prefix "DROP_FORWARD: " --log-level 4
    
    print_success "Journalisation configurée"
    print_warning "Les logs sont visibles avec : sudo journalctl -kf | grep DROP"
}

# Activer IP Forward (routage)
enable_ip_forward() {
    print_info "Activation du routage IP (IP Forward)..."
    
    # Activation immédiate
    echo 1 > /proc/sys/net/ipv4/ip_forward
    
    # Activation permanente
    if grep -q "^#net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    elif ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    fi
    
    sysctl -p &> /dev/null
    
    print_success "IP Forward activé"
}

# Sauvegarder les règles pour persistance
save_rules() {
    print_info "Sauvegarde des règles pour persistance après reboot..."
    
    # Installer iptables-persistent si nécessaire
    if ! dpkg -l | grep -q iptables-persistent; then
        print_info "Installation de iptables-persistent..."
        DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent &> /dev/null
    fi
    
    # Sauvegarder les règles
    iptables-save > /etc/iptables/rules.v4
    
    print_success "Règles sauvegardées dans /etc/iptables/rules.v4"
}

# Afficher les règles actuelles (résumé)
show_rules_summary() {
    print_separator
    echo -e "${GREEN}📋 RÉSUMÉ DES RÈGLES ACTIVES${NC}"
    print_separator
    
    echo -e "\n${YELLOW}🔹 Politiques par défaut :${NC}"
    iptables -L INPUT -n | head -1
    iptables -L OUTPUT -n | head -1
    iptables -L FORWARD -n | head -1
    
    echo -e "\n${YELLOW}🔹 Règles INPUT :${NC}"
    iptables -L INPUT -n -v | head -10
    
    echo -e "\n${YELLOW}🔹 Règles FORWARD :${NC}"
    iptables -L FORWARD -n -v | head -10
    
    echo -e "\n${YELLOW}🔹 Règles NAT :${NC}"
    iptables -t nat -L POSTROUTING -n -v
    
    print_separator
}

# Tester la configuration
test_configuration() {
    print_separator
    echo -e "${GREEN}🧪 TEST DE CONFIGURATION${NC}"
    print_separator
    
    # Test IP Forward
    if [[ $(cat /proc/sys/net/ipv4/ip_forward) -eq 1 ]]; then
        print_success "IP Forward : ACTIVÉ"
    else
        print_error "IP Forward : DÉSACTIVÉ"
    fi
    
    # Test interface LAN
    if ip addr show "$LAN_INTERFACE" | grep -q "$FIREWALL_LAN_IP"; then
        print_success "Interface LAN : $LAN_INTERFACE → $FIREWALL_LAN_IP"
    else
        print_warning "Interface LAN : $LAN_INTERFACE → IP non configurée"
    fi
    
    # Test ping loopback
    if ping -c 1 127.0.0.1 &> /dev/null; then
        print_success "Loopback : OK"
    else
        print_error "Loopback : KO"
    fi
    
    print_separator
}

# Afficher l'aide
show_help() {
    echo "Usage: sudo ./firewall.sh [OPTION]"
    echo ""
    echo "Options :"
    echo "  --apply     Applique la configuration complète du firewall"
    echo "  --flush     Supprime TOUTES les règles (désactive le firewall)"
    echo "  --status    Affiche l'état actuel des règles"
    echo "  --help      Affiche cette aide"
    echo ""
    echo "Exemples :"
    echo "  sudo ./firewall.sh --apply    # Applique la configuration"
    echo "  sudo ./firewall.sh --flush    # Réinitialise tout"
    echo "  sudo ./firewall.sh --status   # Voir les règles"
}

# Désactiver complètement le firewall (reset)
flush_all() {
    print_warning "Désactivation complète du firewall..."
    flush_rules
    
    # Remettre les politiques par défaut à ACCEPT
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    
    # Sauvegarder les règles vides
    save_rules
    
    print_success "Firewall désactivé - TOUT le trafic est maintenant ACCEPTÉ"
    print_warning "Pour réactiver : sudo ./firewall.sh --apply"
}

# Application complète
apply_firewall() {
    print_separator
    echo -e "${GREEN}🔥 DÉPLOIEMENT DU FIREWALL IPTABLES${NC}"
    print_separator
    
    check_root
    check_interfaces
    backup_current_rules
    flush_rules
    set_default_policies
    configure_loopback
    configure_conntrack
    configure_lan_access
    configure_dns
    configure_icmp
    configure_firewall_internet
    configure_forwarding
    configure_nat
    configure_logging
    enable_ip_forward
    save_rules
    
    print_separator
    print_success "🔥 FIREWALL DÉPLOYÉ AVEC SUCCÈS !"
    print_separator
    
    test_configuration
    show_rules_summary
    
    echo ""
    print_info "Commandes utiles :"
    echo "  sudo iptables -L -n -v     # Voir toutes les règles"
    echo "  sudo iptables -t nat -L    # Voir les règles NAT"
    echo "  sudo journalctl -kf | grep DROP  # Voir les paquets bloqués"
}

################################################################################
# MAIN
################################################################################

case "${1:-}" in
    --apply)
        apply_firewall
        ;;
    --flush)
        check_root
        flush_all
        ;;
    --status)
        check_root
        show_rules_summary
        test_configuration
        ;;
    --help)
        show_help
        ;;
    *)
        echo "🔧 Firewall iptables - Script de configuration"
        echo ""
        echo "Utilise --apply, --flush, --status ou --help"
        echo ""
        echo "👉 Exemple : sudo ./firewall.sh --apply"
        ;;
esac
