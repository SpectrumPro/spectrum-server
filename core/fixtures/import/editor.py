import json
import os

def process_json_file(filename):
    # ANSI escape codes for colors
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    CYAN = '\033[96m'
    RESET = '\033[0m'

    # Load the JSON file
    with open(filename, 'r', encoding='utf-8') as file:
        data = json.load(file)
    
    keys = list(data.keys())
    index = 0
    
    while index < len(keys):
        key = keys[index]
        item = data[key]
        
        # Clear the screen
        os.system('clear' if os.name == 'posix' else 'cls')
        
        print(f"{CYAN}Key: {RESET}{key}")
        print(f"{YELLOW}Definition: {RESET}{item.get('definition', 'No definition provided')}")
        print(f"{GREEN}Explanation: {RESET}{item.get('explanation', 'No explanation provided')}\n")
        print(f"{RED}Remaining items: {len(keys) - index - 1}{RESET}\n")
        
        # Prompt user for input
        user_input = input(f"{RED}Should this item be able to fade? (Y/n): {RESET}").strip().lower()
        
        if user_input == 'e':
            break
        elif user_input == 'b':
            index = max(0, index - 1)  # Go back one item, but not before the first
            continue
        
        # Assign can_fade based on input (default to 'y')
        item["can_fade"] = user_input != 'n'
        
        index += 1
    
    # Generate modified filename
    modified_filename = filename.replace('.json', '_modified.json')
    
    # Save the modified JSON back to a file
    with open(modified_filename, 'w', encoding='utf-8') as file:
        json.dump(data, file, indent=4)
    
    print(f"{GREEN}Modified JSON saved as {modified_filename}{RESET}")

# Example usage
process_json_file("GDTFSpecAttributes.json")
