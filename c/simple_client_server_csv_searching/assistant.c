#define _GNU_SOURCE
#include <stdio.h>
#include <string.h> 	
#include <unistd.h> 
#include <sys/types.h> 	
#include <sys/stat.h> 	
#include <fcntl.h> 		
#include <stdlib.h>
#include <sys/ipc.h>
#include <sys/wait.h>

#include "pipes.h"
#include "assistant.h"
 
int oldest_entry_index = 0, curr_index = -1;

int count_lines() {
	FILE *fptr;
	int num_lines = 0;
	char line[MAX_LINE_LENGTH] = {0};
	
	if ((fptr = fopen("history.txt", "r")) == NULL) {
		perror("File not found: ");
		return -1;
	}
	
	while (fgets(line, MAX_LINE_LENGTH, fptr)) num_lines++;
	
	fclose(fptr);
	return num_lines;
}
		

int increment_index() {
	oldest_entry_index++;
	if (oldest_entry_index >= HISTORY_SIZE) oldest_entry_index = 0;
	return oldest_entry_index;
}

int get_index() {
	int index = 0;
	printf(":::%d:::\n", count_lines());
	if (count_lines() >= HISTORY_SIZE) {
		index = oldest_entry_index;
		increment_index();
	}
	else index = ++curr_index;
	return index;
}

/* returns line_number in history if query found, returns -2 on error, returns -1 on not found */
int check_if_in_history(Query q) {
	FILE *fptr;
	char line[MAX_LINE_LENGTH] = {0}, *token, delim[] = "\t\n";
	//char *token;
	int line_number = -1;
	
	if ((fptr = fopen("history.txt", "r")) == NULL) {
		perror("File not found: ");
		return -2;
	}
	
	/* if the employee_name/job_title/status of the query do not match the current line, continue to the next iteration of the while loop 
	 * else if they all match, return the current line number */
	while (fgets(line, MAX_LINE_LENGTH, fptr)) {
		line_number++; // needs to be incremented first because of continue
		
		strtok(line, delim); // emp_id
		//printf("===%s===\n", line);
		//printf("===%s:::%s===\n", strtok(NULL, delim), q.employee_name);
		//if (strncmp(q.employee_name, strtok(NULL, delim), 75)) continue; // emp_name
		if (strcasestr(strtok(NULL, delim), q.employee_name) == NULL) continue;
		//printf("===%s:::%s===\n", strtok(NULL, delim), q.job_title);
		//if (strncmp(q.job_title, strtok(NULL, delim), 75)) continue; // job_title
		if (strcasestr(strtok(NULL, delim), q.job_title) == NULL) continue;
		strtok(NULL, delim); strtok(NULL, delim); strtok(NULL, delim); // base_pay, overtime_pay, benefit
		//printf("===%s:::%s===\n", strtok(NULL, delim), q.status);
		//if (strncmp(q.status, strtok(NULL, delim), 75)) continue;
		if (strcasestr(strtok(NULL, delim), q.status) == NULL) continue;
		
		fclose(fptr);
		return line_number;
	}
	
	fclose(fptr);
	return -1;
}

int write_to_history(Query q, char employee[INFO_SIZE]) {
	FILE *fptr;
	char line[MAX_LINE_LENGTH] = {0}, list[HISTORY_SIZE][MAX_LINE_LENGTH];
	int n = 0, index = get_index();
	
	if ((check_if_in_history(q)) >= 0) return 0;				// if already in history, don't need to do anything
	
	if ((fptr = fopen("history.txt", "r")) == NULL) return -1;	// return -1 if history fails to open in read mode
	for (int i = 0; i < HISTORY_SIZE; i++) {
		fgets(line, MAX_LINE_LENGTH, fptr);
		strcpy(list[i], line);
	}
	fclose(fptr);
	
	strcpy(list[index], employee);
	if ((fptr = fopen("history.txt", "w")) == NULL) return -1;	// return -1 if file fails to open in write mode
	for (int i = 0; i < HISTORY_SIZE; i++) fprintf(fptr, "%s", list[i]); 
	
	fclose(fptr);
	return 0;
}

int read_from_history(Query q) {
	FILE *fptr;
	char line[MAX_LINE_LENGTH] = {0};
	int line_number = -1, n = 0;
	
	if ((line_number = check_if_in_history(q)) < 0) return -1;	// return -1 if not in history file
	if ((fptr = fopen("history.txt", "r")) == NULL) return -2;	// return -2 on error
	
	while (fgets(line, MAX_LINE_LENGTH, fptr)) 
		if (line_number == n++) 
			//if (!fork()) 
				terminal(line, 1);
	
	fclose(fptr);
	return 0;
}
