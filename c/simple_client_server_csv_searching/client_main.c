#include <stdio.h>
#include <string.h> 	
#include <unistd.h> 
#include <sys/types.h> 	
#include <sys/stat.h> 	
#include <fcntl.h> 		
#include <stdlib.h>
#include <sys/ipc.h>
#include <sys/wait.h>
#include <arpa/inet.h> 	// client
#include <sys/socket.h>
#include <netinet/in.h> // server
#include <ctype.h>

#include "manager.h"
#include "pipes.h"
#include "assistant.h"

char ip[24];

int main() {
	/* printing instructions to the user causes the server to not receive anything, even though it is connected */
	//puts("Please enter the server IP: ");				// print instructions to the user
	fgets(ip, 24, stdin);								// get the IP from the user
	ip[strlen(ip)-1] = '\0';							// null terminate the IP string
	
	make_fifos();										// from pipes.h, creates the named pipes: MANAGER_READER, READER_SIGNAL, READER_ASSISTANT
	
	pid_t manager_pid, assistant_pid, wt;				// process IDs
	int status = 0;										// status of wait()
	
	if ((manager_pid = fork()) == 0) manager(); 		// attempt to create a new process for the manager, start the manager on success
	if ((assistant_pid = fork()) == 0) assistant(ip);	// attempt to create a new process for the assistant, start the assistant on success

	while ((wt = wait(&status)) > 0);					// wait until the two spawned processes have exited
	
	unlink(MANAGER_READER);								// unlink from the MANAGER_READER named pipe
	unlink(READER_SIGNAL);								// unlink from the READER_SIGNAL named pipe
	unlink(READER_ASSISTANT);							// unlink from the READER_ASSISTANT named pipe
	
	puts("client main exited");								// indicate that main() successfully exited
	return 0;	
}