;*************************************************************************
;   Name: Niall Murray
;   Date: 4/19/2025
;
;   Description:
;       Wordle recreation in LC3
;   Notes:
;       The guess gets locked in after the 5th letter, so make sure you type what you want!
;       Backspace, however can be pressed to reset the guess before the 5th letter
;   Register Dictionary:
;       R0: Used for trap display and input
;       R1: Storage for calculations + counter for number of guesses used
;       R2: Storage for calculations + holds address of current user guess
;       R3: Used to store the game selected word in memory + Counter for each guess (5 char limit)
;       R4: Changes depending on proper input + used to check for the limit of R3
;       R5: Win condition of the game
;       R6:
;       R7: JSR + RET
;************************************************************************

    .ORIG x3000
    
    JSR JUMP_TO_ASCII
    PUTS ; ASCII ART HELL YEAH!
    
    NEW_GAME
    
    JSR GET_RANDOM
   
    ; First, take ASCII value of char inputted by user and use it as a seed to choose a word from WORD_LIST
    ; and store it in RANDOM_WORD for later use in the game
   
    LD R1, NUM_OF_WORDS
   
    REDUCE ; R0 % 36
    ADD R0, R0, R1
    BRzp REDUCE
       
    NOT R1, R1 ; Since R1 will only be neg here, add 36 back to make it pos
    ADD R1, R1, #1
    ADD R0, R0, R1 ; R0 will between 0 and 35
   
    AND R1, R1, #0
    ADD R1, R1, R0 ; Duplicates R0 into R1
   
    AND R2, R2, #0
    ADD R2, R2, #4 ; Length of each word in WORD_LIST - 1 (since it already has the value x1, just needs 4 more)
   
    SUMMATE ; R0 * 5 basically since each word is 5 letters
    ADD R0, R0, R1
    ADD R2, R2, #-1
    BRp SUMMATE
   
    JSR JUMP_TO_WL ; Loads beginning address of WORD_LIST by jumping to a subroutine
    ADD R1, R1, R0 ; Adds offset of chosen key: [ASCII(user input) % 36] * 5
   
    ADD R2, R2, #5 ; Initializes counter
    LEA R3, RANDOM_WORD ; Start of BLKW of RANDOM_WORD
   
    STORE_WORD
    LDR R0, R1, #0 ; Loads n char from WORD_LIST + offset
    STR R0, R3, #0 ; Stores n char of chosen word at current RANDOM_WORD pos
    ADD R3, R3, #1 ; Moves to next mem spot of RANDOM_WORD
    ADD R1, R1, #1 ; Moves to next char of word
    ADD R2, R2, #-1 ; Counter decrement
    BRp STORE_WORD
    
    ; All registers are free now
    
    ; Second, game loop
    
    LEA R1, SYNCED_CHARS
    JSR INIT_SYNCED ; Sets SYNCED_CHARS to all underscores
    AND R1, R1, #0
    
    JSR INIT_EXISTING
    
    JSR PRINT_PROGRESS
    
    NEXT_GUESS
    LEA R2, CURRENT_GUESS
    ADD R1, R1, #1 ; Increment num of guesses
    JSR PRINT_GUESS_PROMPT  ; Args: R1, # of guesses
    
    AND R3, R3, #0 ; Clear R3 (Char count in guess)
    
        READ_GUESS
        GETC ; Gets a char
        ADD R3, R3, #1
    
        JSR PROCESS_INPUT ; Args: R0 (input char), Ret: R4 (error)
        AND R4, R4, R4
        BRz INVALID_GUESS ; If guess invalid, quit loop iteration early
        BRp VALID_INPUT ; If input was alright (not backspace)
        
        ; Else, clear guess (backspace was typed)
        ADD R1, R1, #-1
        BRnzp NEXT_GUESS ; Restart guess cleared
    
        VALID_INPUT
        OUT ; Echos that char
        
        STR R0, R2, #0 ; Stores char in mem
        ADD R2, R2, #1 ; Next mem spot
    
        AND R4, R3, R3 ; Loads R3 into R4
        ADD R4, R4, #-5 ; Checks if user has typed 5 letters yet
        BRn READ_GUESS ; Loop if not
        BRnzp FINISH_GUESS ; Skip regardless if loop finished
    
        INVALID_GUESS
        ADD R1, R1, #-1 ; Reset # of guesses back to previous loop iteration
        LEA R0, GUESS_INVALID
        PUTS ; Prints GUESS_INVALID
        BRnzp NEXT_GUESS ; Restart guess cleared
        
        FINISH_GUESS ; If all's fine
        
        JSR CHECK_WIN
        AND R5, R5, R5
        BRz PLAYER_WINS ; If R5 = 0 from CHECK_WIN, else cont game
        
        JSR INIT_EXISTING
        JSR FIND_EXISTING
        JSR PRINT_PROGRESS
    
    AND R0, R1, R1
    ADD R0, R0, #-6 ; Checks if # of guesses surpasses the limit (6)
    
    BRn NEXT_GUESS
    
    ; Game over, print win/loss messages
    
    AND R5, R5, R5
    BRnp PLAYER_LOSES
    
    PLAYER_WINS
    LEA R0, WIN_MESSAGE
    PUTS ; Print win message
    BRnzp PASTE
    
    PLAYER_LOSES
    LEA R0, LOSE_MESSAGE
    PUTS ; Print lose message
    BRnzp PASTE
    
    PASTE
    LEA R0, RANDOM_WORD
    PUTS ; Prints winner message
    
    JSR CONTINUE_GAME
    AND R1, R1, R1
    BRp NEW_GAME
    
    HALT
    
NUM_OF_WORDS    .FILL xFFDC ; -36

CONTINUE_PROMPT .STRINGZ    "Press a random key to continue...\n"
GUESS_INVALID   .STRINGZ    " !!! Invalid guess! Must not include non-alphabet characters!"
END_GAME        .STRINGZ    "Bye bye!\n"

WIN_MESSAGE     .STRINGZ    "\n\nYou win!!\nYou guessed the right word: "

RANDOM_WORD     .BLKW #6 ; Dynamic allocation slotted for game selected word
CURRENT_GUESS   .BLKW #5 ; Dynamic allocation slotted for user inputted word
SYNCED_CHARS    .BLKW #6 ; Dynamic allocation slotted for similarities between both words
EXISTING_CHARS  .BLKW #6 ; Array used to store existing chars in guess

LOSE_MESSAGE    .STRINGZ    "\n\nSorry, you ran out of guesses!\nThe correct word was: "

;************************************************************************
;   Subroutine: PRINT_GUESS_PROMPT
;   Description:
;       Prints "Guess #n: "
;   Register Dictionary:
;       R0: Used for printing to screen
;       R1: (Arg) # of guesses so far
;************************************************************************

PRINT_GUESS_PROMPT
    ST R0, SAVE_R0_PG
    
    LEA R0, GUESS_PROMPT
    PUTS ; Prints guess prompt
    
    LD R0, DEC_TO_ASCII
    ADD R0, R0, R1
    OUT ; Prints the number of guess
    
    LEA R0, GUESS_PROMPT_2
    PUTS ; Also same

    LD R0, SAVE_R0_PG
RET
    
SAVE_R0_PG   .BLKW #1

DEC_TO_ASCII    .FILL x0030 ; 48

GUESS_PROMPT    .STRINGZ    "\nGuess #"
GUESS_PROMPT_2  .STRINGZ    ": "

;************************************************************************
;   Subroutine: PRINT_PROGRESS
;   Description:
;       Prints out a string of indentical letters in user guess compared to word (prints current guess basically,
;       just meant to be ran after FIND_IDENTICAL subroutine)
;   Register Dictionary:
;       R0: Used for printing to screen
;       R1: Position in memory of SYNCED_CHARS and EXISTING_CHARS
;************************************************************************

PRINT_PROGRESS
    ST R0, SAVE_R0_P
    ST R1, SAVE_R1_P
    
    LEA R0, FOUND
    PUTS ; Prints FOUND
    
    LEA R1, SYNCED_CHARS
    
    PRINT_LOOP_P1
    LDR R0, R1, #0
    BRz EARLY_P1 ; If null term, quit to P2 early
    OUT ; Prints n char of current guess
    LD R0, SPACE
    OUT ; Prints a space
    ADD R1, R1, #1
    BRp PRINT_LOOP_P1
    
    EARLY_P1
    LEA R0, EXISTING
    PUTS
    
    LEA R1, EXISTING_CHARS
    
    PRINT_LOOP_P2
    LDR R0, R1, #0
    BRz EARLY_P2 ; If null term, quit early
    OUT ; Prints n char of current guess
    LD R0, COMMA
    OUT ; Prints a comma
    LD R0, SPACE
    OUT ; Prints a space
    ADD R1, R1, #1
    BRp PRINT_LOOP_P2
    
    EARLY_P2
    LD R0, SAVE_R0_P
    LD R1, SAVE_R1_P
RET
    
SAVE_R0_P  .BLKW #1
SAVE_R1_P  .BLKW #1
SAVE_R2_P  .BLKW #1
    
FOUND       .STRINGZ    "\n\nFound letters: "
EXISTING    .STRINGZ    "\nExisting letters: "

COMMA   .FILL   x002C ; ','
SPACE   .FILL   x0020 ; ' '
NEWLINE .FILL   x000A ; '\n'

;************************************************************************
;   Subroutine: CHECK_WIN
;   Description:
;       Finds all the equal letters in both the game word and user word. Replaces non similar letters in user word with an underscore. If all right, player wins
;   Register Dictionary:
;       R0: Position in memory of game word
;       R1: Position in memory of user word
;       R2: Loads current letter of game word + loads underscore
;       R3: Loads current letter of user word + used to check if sync spot already has a letter in it
;       R4: Position in memory of synced chars
;       R5: Number of total similarities + (ret) returns 0 if player won, and 5 similarities are found
;************************************************************************

CHECK_WIN
    ST R0, SAVE_R0_CW
    ST R1, SAVE_R1_CW
    ST R2, SAVE_R2_CW
    ST R3, SAVE_R3_CW
    ST R4, SAVE_R4_CW
    
    AND R5, R5, #0
    ADD R5, R5, #5

    LEA R0, RANDOM_WORD ; Game word
    LEA R1, CURRENT_GUESS ; User inputted word
    LEA R4, SYNCED_CHARS ; Similarities between game and user word
    
    CYCLE_BOTH_CW
    LDR R2, R0, #0 ; Loads n letter of game word in R2
    BRz EARLY_CW ; If it's the null term, quit early
    LDR R3, R1, #0 ; Loads n letter of user word into R3
    
    NOT R3, R3
    ADD R3, R3, #1
    ADD R3, R3, R2 ; Checks if R2 and R3 are equal
    BRz IDENTICAL_CW
    
    ; If they aren't equal
    ADD R5, R5, #-1 ; One similarity found!
    
    LD R2, UNDERSCORE ; Loads underscore
    LDR R3, R4, #0
    NOT R3, R3
    ADD R3, R3, #1
    ADD R3, R3, R2
    BRnp SKIP_ITERATION
    
    IDENTICAL_CW
    STR R2, R4, #0 ; Stores current char in SYNCHED_CHARS only if it's an underscore
    
    SKIP_ITERATION
    ADD R0, R0, #1 ; Next letter of game word
    ADD R1, R1, #1 ; Next letter of user word
    ADD R4, R4, #1 ; Next spot in similarities
    BRp CYCLE_BOTH_CW ; Loops 5 times
    
    EARLY_CW
    ADD R5, R5, #-5
    BRnp NOT_WIN
    
    NOT_WIN
    LD R0, SAVE_R0_CW
    LD R1, SAVE_R1_CW
    LD R2, SAVE_R2_CW
    LD R3, SAVE_R3_CW
    LD R4, SAVE_R4_CW
    
RET

SAVE_R0_CW  .BLKW #1
SAVE_R1_CW  .BLKW #1
SAVE_R2_CW  .BLKW #1
SAVE_R3_CW  .BLKW #1
SAVE_R4_CW  .BLKW #1
SAVE_R5_CW  .BLKW #1

UNDERSCORE      .FILL x005F ; 95 '_'

;************************************************************************
;   Subroutine: FIND_EXISTING
;   Description:
;       Finds all similar letters between current guess and random word, not mattering if they're in the same respective spot or not
;   Register Dictionary:
;       R0: Position in memory of game word
;       R1: Position in memory of user word
;       R2: Outer loop counter
;       R3: Inner loop counter
;       R4: Loaded letter of game word
;       R5: Loaded letter of the user word + negated form for comparison
;       R6: Position in memory of synced chars
;************************************************************************

FIND_EXISTING
    ST R0, SAVE_R0_FM
    ST R1, SAVE_R1_FM
    ST R2, SAVE_R2_FM
    ST R3, SAVE_R3_FM
    ST R4, SAVE_R4_FM
    ST R5, SAVE_R4_FM
    ST R6, SAVE_R4_FM

    LEA R0, RANDOM_WORD ; Game word
    LEA R6, EXISTING_CHARS ; Misplaced chars
    
    ; Inits R2 to 5 (game word loop counter)
    AND R2, R2, #0
    ADD R2, R2, #5
    
    ; Outer for loop
    CYCLE_GAME_FM
    LEA R1, CURRENT_GUESS ; User inputted word
    LDR R4, R0, #0 ; Loads first letter of game word
    
    ; Inits R3 to 5 (user word loop counter)
    AND R3, R3, #0
    ADD R3, R3, #5
    
        ; Inner for loop
        CYCLE_USER_FM
        LDR R5, R1, #0
        
        ; Negates R5 and compares it with R4
        NOT R5, R5
        ADD R5, R5, #1
        ADD R5, R4, R5 ; R4 still has normal letter
        BRnp NOT_EQUAL_FM ; If it's 0 continue
        
        STR R4, R6, #0 ; Stores it in MISPLACED_CHARS
        ADD R6, R6, #1 ; Moves to next spot
        BRnzp DECREMENT_EARLY_FM
        
        NOT_EQUAL_FM
        ADD R1, R1, #1 ; Move to next letter in user word
        ADD R3, R3, #-1 ; decrement user word loop counter
        BRp CYCLE_USER_FM
        
    DECREMENT_EARLY_FM
    ADD R0, R0, #1 ; Move to next letter in game word
    ADD R2, R2, #-1 ; decrement game word loop counter
    BRp CYCLE_GAME_FM ; Loop if 0 <
    
    LD R0, SAVE_R0_FM
    LD R1, SAVE_R1_FM
    LD R2, SAVE_R2_FM
    LD R3, SAVE_R3_FM
    LD R4, SAVE_R4_FM
    LD R5, SAVE_R4_FM
    LD R6, SAVE_R4_FM
RET

SAVE_R0_FM  .BLKW #1
SAVE_R1_FM  .BLKW #1
SAVE_R2_FM  .BLKW #1
SAVE_R3_FM  .BLKW #1
SAVE_R4_FM  .BLKW #1
SAVE_R5_FM  .BLKW #1
SAVE_R6_FM  .BLKW #1

;************************************************************************
;   Subroutine: INIT_EXISTING
;   Description:
;       Initializes EXISTING_CHARS to 0s
;   Register Dictionary:
;       R0: EXISTING_CHARS
;       R1: Counter
;       R2: Used to for 0
;************************************************************************

INIT_EXISTING
    ST R0, SAVE_R0_INITE
    ST R1, SAVE_R1_INITE
    ST R2, SAVE_R2_INITE
    
    LEA R0, EXISTING_CHARS
    
    AND R1, R1, #0
    ADD R1, R1, #5
    
    AND R2, R2, #0
    
    INITE_LOOP
    STR R2, R0, #0
    ADD R0, R0, #1
    ADD R1, R1, #-1
    BRp INITE_LOOP
    
    LD R0, SAVE_R0_INITE
    LD R1, SAVE_R1_INITE
    LD R2, SAVE_R2_INITE
RET

SAVE_R0_INITE  .BLKW #1
SAVE_R1_INITE  .BLKW #1
SAVE_R2_INITE  .BLKW #1

;************************************************************************
;   Subroutine: INIT_SYNCED
;   Description:
;       Initializes SYNCED_CHARS to all underscores
;   Register Dictionary:
;       R0: Counter
;       R1: (arg) SYNCED_CHARS
;       R2: Used to test for backspace
;************************************************************************

INIT_SYNCED
    ST R0, SAVE_R0_INITS
    ST R2, SAVE_R2_INITS
    
    AND R0, R0, #0
    ADD R0, R0, #5
    
    LD R2, UNDERSCORE
    
    INITS_LOOP
    STR R2, R1, #0
    ADD R1, R1, #1
    ADD R0, R0, #-1
    BRp INITS_LOOP
    
    LD R0, SAVE_R0_INITS
    LD R2, SAVE_R2_INITS
RET
    
SAVE_R0_INITS   .BLKW #1
SAVE_R2_INITS   .BLKW #1

;************************************************************************
;   Subroutine: CONTINUE_GAME
;   Description:
;       Checks if user wants to play again
;   Register Dictionary:
;       
;************************************************************************

CONTINUE_GAME
    INVALID_CG
    LEA R0, PLAY_AGAIN
    PUTS
    
    AND R1, R1, #0 ; Clears R1
    
    GETC ; Get char input from
    OUT ; Echos it
    
    LD R2, ASCII_NO
    ADD R1, R0, R2
    BRnp CHECK_Y
    BRz RETURN_CG ; If user typed n, R1 will already be 0
    
    CHECK_Y
    LD R2, ASCII_YES
    ADD R1, R0, R2
    BRnp INVALID_CG
    
    ADD R1, R1, #1
    LD R0, NEWLINE ; Steals from another subroutine
    OUT
    
    RETURN_CG
RET
    
PLAY_AGAIN  .STRINGZ    "\nPlay again? (y/n): "

ASCII_NO    .FILL   xFF92 ; - ascii of n
ASCII_YES   .FILL   xFF87 ; - ascii of y

;************************************************************************
;   Subroutine: PROCESS_INPUT
;   Description:
;       Checks if a character is in the alphabet, capitalizes if it's lowercase
;   Register Dictionary:
;       R0: (Arg) Char input
;       R1: Loading bounds check
;       R4: Return value (boolean)
;************************************************************************

PROCESS_INPUT
    ST R1, SAVE_R1_PI
    ST R2, SAVE_R2_PI
    
    AND R4, R4, #0 ; Return value 1,0 if ASCII letter or not
    AND R2, R2, #0
    
    ; Check if input is equal to backspace
    ADD R2, R2, R0
    ADD R2, R2, #-8
    BRnp NOT_CLEAR
    
    ; If it is, return -1
    ADD R4, R4, #-1
    BRnzp INVALID
    
    NOT_CLEAR
    
    ; Checks bounds of user inputted char (R0) and whether it's lowercase or not
    LD R1, LOWERBOUND_CHECK
    ADD R1, R0, R1
    BRn INVALID
    
    LD R1, UPPERBOUND_CHECK
    ADD R1, R0, R1
    BRp INVALID
    
    LD R1, LOWERCASE_CHECK
    ADD R1, R0, R1
    BRn VALID
    
    ; Capitalizes
    LD R1, CAPITALIZE
    ADD R0, R0, R1
    
    VALID
    ADD R4, R4, #1
    
    INVALID
    LD R1, SAVE_R1_PI
    LD R2, SAVE_R2_PI
RET
    
SAVE_R1_PI          .BLKW #1
SAVE_R2_PI          .BLKW #1

LOWERBOUND_CHECK    .FILL xFFBF ; -65
UPPERBOUND_CHECK    .FILL xFF86 ; -122
LOWERCASE_CHECK     .FILL xFF9F ; -97
CAPITALIZE          .FILL xFFE0 ; -32

;************************************************************************
;   Subroutine: GET_RANDOM
;   Description:
;       Gets a random number from memory values past x3400 when using random system stuff its cool
;   Register Dictionary:
;       R0: (ret) Random number
;       R1: # of games ran
;************************************************************************

GET_RANDOM
    ST R1, SAVE_R1_RANDOM
    
    LD R1, GAME_RUNS ; Loads # of games ran
    ADD R1, R1, #1  ; Adds 1 to # of games ran
    ST R1, GAME_RUNS
    
    LDI R0, RANDOM_START ; Indirectly loads random number
    ADD R0, R0, R1
    
    BRzp POS ; Flip it to pos if it's negative
    NOT R0, R0
    ADD R0, R0, #1
    POS
    
    LD R1, SAVE_R1_RANDOM
RET

SAVE_R1_RANDOM  .BLKW #1
GAME_RUNS       .BLKW #1
RANDOM_START    .FILL x3750

;************************************************************************
;   Subroutine: JUMP_TO_WL
;   Description:
;       Serves as a median to load the starting address of word list into a register since the string is so long
;   Register Dictionary:
;       R1: (ret) WORD_LIST
;************************************************************************

JUMP_TO_WL
    LEA R1, WORD_LIST
RET

WORD_LIST   .STRINGZ    "CHARMLOGINSTACKSPINEQUERYCRANECODECGRASPPIXELCLOUDLOGICFLICKARRAYFLINTBRISKMIRTHTRICKWHILECACHEBLAZEPATCHTOKENDEBUGINPUTALERTBLENDSHINEGLIDETRACEDRIFTABOUTHELLOGUESSRACERPHONESPEED"

;************************************************************************
;   Subroutine: JUMP_TO_ASCII
;   Description:
;       Serves as a median to load the starting address of wordle ascii art into a register since the string is so long
;   Register Dictionary:
;       R0: (ret) ASCII_ART
;************************************************************************

JUMP_TO_ASCII
    LEA R0, ASCII_ART
RET
    
ASCII_ART   .STRINGZ    " __      __                     .___.__           \n/  \    /  \  ____  _______   __| _/|  |    ____  \n\   \/\/   / /  _ \ \_  __ \ / __ | |  |  _/ __ \ \n \        / (  <_> ) |  | \// /_/ | |  |__\  ___/ \n  \__/\  /   \____/  |__|   \____ | |____/ \___  >\n       \/                        \/            \/ \n"

;************************************************************************

    .END