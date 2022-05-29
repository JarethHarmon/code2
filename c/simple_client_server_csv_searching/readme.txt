# Description #
	> This was originally a group project for college. I have rewritten it to be cleaner and to be entirely my own code.
	
	Server:
		> prints public IP of the computer it was run on
		> listens for a connection from the client
		> loads the input files (basically csv but delimited by tabs instead of commas) into arrays
		> waits for a query from the assistant
		> searches the arrays using threads
		> returns the employee info if found
	Client:
		> waits for the user to enter the IP of the server
		> prompts and waits for input from the user
		> searches history file for the query and prints the result if found
		> else sends the query to the server and then waits for and prints the result
	
# Compile #
	# WSL (CMD prompt) #
		// need to run both of these commands on the drive that this program is stored (if running on WSL)
		// forcibly dismounts the E: drive
		wsl sudo umount -l /mnt/e

		//re-mounts the E: drive with metadata enabled (to allow pipe creation with mkfifo())
		wsl sudo mount -t drvfs E: /mnt/e -o metadata

		# Server #
			wsl gcc server_main.c pipes.c server.c assistant.c -o server.o -lpthread
			wsl ./server.o
	
		# Client #
			wsl gcc client_main.c assistant.c pipes.c manager.c -o client.o
			wsl ./client.o


	# Linux #
		# Server #
			gcc server_main.c pipes.c server.c assistant.c -o server.o -lpthread
			./server.o

		# Client #
			gcc client_main.c assistant.c pipes.c manager.c -o client.o
			./client.o
# Use #
	> run the server
	> run the client
	> enter the IP that the server prints into the client
	> enter information into the client as prompted (partial queries work, can use ID_Name.txt and Salaries.txt for reference)
	> should print employee information from history.txt if it is present there, else it should query the server for the employee and then print the info
