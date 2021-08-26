class Style:
    BOLD = "\033[1m"
    DIM = "\033[2m"
    ITALIC = "\033[3m"
    UNDERLINE = "\033[4m"
    STRIKETHROUGH = "\033[9m"
    BLINK = "\033[5m"
    RESET = "\033[0m"


class Foreground:
    BLACK = "\033[0;30m"
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[0;33m"
    BLUE = "\033[0;34m"
    PURPLE = "\033[0;35m"
    CYAN = "\033[0;36m"
    WHITE = "\033[0;37m"

    # Bold
    BBlack = "\033[1;30m"
    BRed = "\033[1;31m"
    BGreen = "\033[1;32m"
    BYellow = "\033[1;33m"
    BBlue = "\033[1;34m"
    BPurple = "\033[1;35m"
    BCyan = "\033[1;36m"
    BWhite = "\033[1;37m"

    # Underline
    UBlack = "\033[4;30m"
    URed = "\033[4;31m"
    UGreen = "\033[4;32m"
    UYellow = "\033[4;33m"
    UBlue = "\033[4;34m"
    UPurple = "\033[4;35m"
    UCyan = "\033[4;36m"
    UWhite = "\033[4;37m"

    # High Intensity
    IBlack = "\033[0;90m"
    IRed = "\033[0;91m"
    IGreen = "\033[0;92m"
    IYellow = "\033[0;93m"
    IBlue = "\033[0;94m"
    IPurple = "\033[0;95m"
    ICyan = "\033[0;96m"
    IWhite = "\033[0;97m"

    # Bold High Intensity
    BIBlack = "\033[1;90m"
    BIRed = "\033[1;91m"
    BIGreen = "\033[1;92m"
    BIYellow = "\033[1;93m"
    BIBlue = "\033[1;94m"
    BIPurple = "\033[1;95m"
    BICyan = "\033[1;96m"
    BIWhite = "\033[1;97m"


class Background:
    Black = "\033[40m"
    Red = "\033[41m"
    Green = "\033[42m"
    Yellow = "\033[43m"
    Blue = "\033[44m"
    Purple = "\033[45m"
    Cyan = "\033[46m"
    White = "\033[47m"

    # High Intensity backgrounds
    IBlack = "\033[0;100m"
    IRed = "\033[0;101m"
    IGreen = "\033[0;102m"
    IYellow = "\033[0;103m"
    IBlue = "\033[0;104m"
    IPurple = "\033[0;105m"
    ICyan = "\033[0;106m"
    IWhite = "\033[0;107m"
