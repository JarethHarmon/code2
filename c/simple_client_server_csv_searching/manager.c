#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>

#include "manager.h"
#include "pipes.h"

int manager() {	
	int fd;
	if ((fd = open_write_pipe_manager_reader()) < 0) exit(1);		// open the pipe to the reader
	puts("Type 'quit' to stop entering queries.");	
	
	Query q;
	while(1) {
		puts("\nPlease enter the employee name: ");
		fgets(q.employee_name, 75, stdin);							// get the employee name from the user
		q.employee_name[strlen(q.employee_name)-1] = '\0';			// null terminate the input string
		if (!strncasecmp(q.employee_name, "quit", 6)) break;		// check if they chose to quit
		
		puts("\nPlease enter the employee job title: ");
		fgets(q.job_title, 75, stdin);								// get the employee job title from the user
		q.job_title[strlen(q.job_title)-1] = '\0';					// null terminate the input string
		if (!strncasecmp(q.job_title, "quit", 6)) break;			// check if they chose to quit
		
		puts("\nPlease enter the employee status (PT/FT): ");
		fgets(q.status, 75, stdin);									// get the employee status from the user
		q.status[strlen(q.status)-1] = '\0';						// null terminate the input string
		if (!strncasecmp(q.status, "quit", 6)) break;				// check if they chose to quit
		
		manager_send_query(q, fd);									// send the query to the reader
		sleep(1);
	}
	
	close(fd);														// close the pipe to the reader
	puts("manager exited");											// indicate that manager successfully exited
	exit(0);														// exit instead of return since this is a spawned process
}