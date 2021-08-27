COLORS = {
    "GREEN": "\033[92m",
    "RED": "\033[91m",
    "YELLOW": "\033[93m",
    "PURPLE": "\033[95m",
    "ENDC": "\033[0m",
}

def fancy_message(message_type: str, message: str):
    if message_type == "info":
        print(COLORS["GREEN"], "[+] INFO:", COLORS["ENDC"], message) 
    elif message_type == "warn":
        print(COLORS["YELLOW"], "[*] WARN:", COLORS["ENDC"], message) 
    elif message_type == "error":
        print(COLORS["RED"], "[!] ERROR:", COLORS["ENDC"], message)
    else:
        print(COLORS["ENDC"], "[?] UNKNOWN: ", COLORS["ENDC"], message)
