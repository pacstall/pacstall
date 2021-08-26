from api.color import Foreground as fg
from api.color import Style as st
from os import environ


"""
Pacstall's messaging API

Methods
-------
fancy (type, message): Print fancy messages
ask (question, default="nothing"): Ask Y/N questions
"""


def fancy(type: str, message: str) -> None:
    """
    Print fancy messages

    Parameters
    ----------
    type (str): Type of message - "info" or "warn" or "error".
    message (str): Message.
    """

    # type: prompt
    types = {
        "info": f"[{fg.BGreen}+{st.RESET}] INFO:",
        "warn": f"[{fg.BYellow}*{st.RESET}] WARNING:",
        "error": f"[{fg.BRed}!{st.RESET}] ERROR:",
    }
    prompt = types.get(type, f"[{st.BOLD}?{st.RESET}] UNKNOWN:")
    print(f"{prompt} {message}")


def ask(question: str, default: str = "nothing") -> str:
    """
    Ask Y/N questions

    Parameters
    ----------
    question (str): Question.
    default="nothing" (str): Default option - "Y" or "N" or nothing.

    Returns
    -------
    str: Returns the user's reply

    """
    # default: prompt
    defaults = {
        "Y": f"[{fg.BIGreen}Y{st.RESET}/{fg.RED}n{st.RESET}]",
        "N": f"[{fg.GREEN}y{st.RESET}/{fg.BIRed}N{st.RESET}]",
    }

    prompt = defaults.get(default, f"[{fg.GREEN}y{st.RESET}/{fg.RED}n{st.RESET}]")
    if not environ.get("PACSTALL_DISABLE_PROMPTS"):
        reply = input(f"{question} {prompt} ").upper()

        if not reply:
            reply = default
    else:
        reply = default

        if default != "nothing":
            print(f"{question} {prompt} {default}")

    while True:
        if reply == "Y" or reply == "N":
            return reply
        else:
            reply = input(f"{question} {prompt} ").upper()
