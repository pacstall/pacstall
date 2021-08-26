from termcolor import colored


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
        "info": f"[{colored('+', 'green', attrs=['bold'])}] INFO:",
        "warn": f"[{colored('*', 'yellow', attrs=['bold'])}] WARNING:",
        "error": f"[{colored('!', 'red', attrs=['bold'])}!] ERROR:",
    }
    prompt = types.get(type, f"[{colored('?', attrs=['bold'])}] UNKNOWN:")
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
        "Y": f"[{colored('Y', 'green', attrs=['bold'])}/{colored('n', 'red')}]",
        "N": f"[{colored('y', 'green')}/{colored('N', 'red', attrs=['bold'])}]",
    }

    prompt = defaults.get(default, f"[{colored('y', 'green')}/{colored('n', 'red')}]")
    print(prompt)
    reply = input(f"{question} {prompt} ").upper()

    if not reply:
        reply = default

    while True:
        if reply == "Y" or reply == "N":
            return reply
        else:
            reply = input(f"{question} {prompt} ").upper()
