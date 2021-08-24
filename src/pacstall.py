import os

# ANSI CODE ESCAPE VALUES
COLORS = {
    "GREEN": "\033[92m",
    "RED": "\033[91m",
    "YELLOW": "\033[93m",
    "PURPLE": "\033[95m",
    "ENDC": "\033[0m",
}

# FANCY MESSAGE
def fancy_message(message_type: str, message: str):
    # INFO
    if message_type == "info":
        print(COLORS["GREEN"], "[+] INFO:", COLORS["ENDC"], message)
    # WARN
    elif message_type == "warn":
        print(COLORS["YELLOW"], "[*] WARN:", COLORS["ENDC"], message)
    # ERROR
    elif message_type == "error":
        print(COLORS["RED"], "[!] ERROR:", COLORS["ENDC"], message)
    # UNKNOWN
    else:
        print(COLORS["ENDC"], "[?] UNKNOWN: ", COLORS["ENDC"], message)

def ask(ques: str, qtype=None):
    default = qtype
    if default == "Y":
        print(ques, "[" + COLORS["GREEN"] + "Y" + COLORS["ENDC"] + "/n]")
    elif default == "N":
        print(ques, "[y/" + COLORS["RED"] + "N]" + COLORS["ENDC"])
    else:
        print(ques, "[y/n]")
    a = { 'Y': 1, 'N': 0 }
    while(True):
        if os.environ.get('PACSTALL_PROMPTS_DISABLED') == True:
            return default

        answer = input().upper()
        if answer in ["Y", "N"]:
            return a[answer]
        elif default is not None:
            return a[qtype]
