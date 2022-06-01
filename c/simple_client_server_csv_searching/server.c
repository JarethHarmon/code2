#define _GNU_SOURCE
#include <stdio.h> 
#include <stdlib.h> 
#include <string.h> 
#include <unistd.h>
#include <arpa/inet.h> 	// client
#include <sys/socket.h>
#include <netinet/in.h> // server
#include <ctype.h>
#include <pthread.h>

#include "pipes.h"
#include "server.h"

// FILE_LINE_COUNT could be calculated fairly easily by just iterating over the entire file once and incrementing a counter
IDName list_id_name[FILE_LINE_COUNT] = {0};
Salaries list_salaries[FILE_LINE_COUNT] = {0};
Satisfaction list_satisfaction[FILE_LINE_COUNT] = {0};

Salaries salaries_search_result;
Satisfaction satisfaction_search_result;
EmployeeInformation employee_info;

const char delim[] = "\t\n\r";

int load_id_name() {
	FILE *fptr;
	char line[MAX_LINE_LENGTH], first_line[MAX_LINE_LENGTH] = {0};
	if ((fptr = fopen("ID_Name.txt", "r")) == NULL) return -1;
	
	fgets(first_line, MAX_LINE_LENGTH, fptr);
	int n = 0;
		
	while (fgets(line, MAX_LINE_LENGTH, fptr)) {
		 strcpy(list_id_name[n].emp_id, strtok(line, delim));
		 strcpy(list_id_name[n].emp_name, strtok(NULL, delim));
		 n++;
	}
	fclose(fptr);
	return 0;
}

int load_salaries() {
	FILE *fptr;
	char line[MAX_LINE_LENGTH];
	if ((fptr = fopen("Salaries.txt", "r")) == NULL) return -1;
	
	fgets(line, MAX_LINE_LENGTH, fptr);
	int n = 0;
	
	while (fgets(line, MAX_LINE_LENGTH, fptr)) {
		strcpy(list_salaries[n].emp_id, strtok(line, delim));
		strcpy(list_salaries[n].job_title, strtok(NULL, delim));
		strcpy(list_salaries[n].base_pay, strtok(NULL, delim));
		// there is at least one line in the csv file (emp_id:81392) that does not have a base pay listed
		if (!strncmp(list_salaries[n].base_pay, "0", 3)) strcpy(list_salaries[n].overtime_pay, "0");
		else strcpy(list_salaries[n].overtime_pay, strtok(NULL, delim));
		strcpy(list_salaries[n].benefit, strtok(NULL, delim));
		// there is at least one line in the csv file (emp_id:106696) that does not have a benefit listed
		if ((!strncasecmp(list_salaries[n].benefit, "FT", 4)) || (!strncasecmp(list_salaries[n].benefit, "PT", 4))) {
			strcpy(list_salaries[n].status, list_salaries[n].benefit);
			strcpy(list_salaries[n].benefit, "0");
		} else strcpy(list_salaries[n].status, strtok(NULL, delim));
		n++;
	}
	fclose(fptr);
	return 0;
}

int load_satisfaction() {
	FILE *fptr;
	char line[MAX_LINE_LENGTH];
	if ((fptr = fopen("SatisfactionLevel.txt", "r")) == NULL) return -1;
	
	fgets(line, MAX_LINE_LENGTH, fptr);
	int n = 0;
	
	while (fgets(line, MAX_LINE_LENGTH, fptr)) {
		strcpy(list_satisfaction[n].emp_id, strtok(line, delim));
		strcpy(list_satisfaction[n].satisfaction_level, strtok(NULL, delim));
		strcpy(list_satisfaction[n].number_projects, strtok(NULL, delim));
		strcpy(list_satisfaction[n].avg_monthly_hours, strtok(NULL, delim));
		strcpy(list_satisfaction[n].years_at_company, strtok(NULL, delim));
		strcpy(list_satisfaction[n].work_accidents, strtok(NULL, delim));
		strcpy(list_satisfaction[n].promotions_last_5_years, strtok(NULL, delim));
		n++;
	}
	fclose(fptr);
	return 0;
}

/* note about threads: they were created according to the assignment to search these two arrays for the employee ID
 * obviously the IDs are ordered sequentially with no gaps, so you could just directly access the index of the arrays
 * though this method does have the benefit of working with random orders/missing IDs, etc  (this method also has the 
 * benefit of not needing to parse the char arrays into integers */

void *salaries(void *b) {
	for (int i = 0; i < FILE_LINE_COUNT; i++) {
		if (!strncmp(list_salaries[i].emp_id, employee_info.emp_id, 10)) {
			strcpy(salaries_search_result.emp_id, list_salaries[i].emp_id);
			strcpy(salaries_search_result.job_title, list_salaries[i].job_title);
			strcpy(salaries_search_result.base_pay, list_salaries[i].base_pay);
			strcpy(salaries_search_result.overtime_pay, list_salaries[i].overtime_pay);
			strcpy(salaries_search_result.benefit, list_salaries[i].benefit);
			strcpy(salaries_search_result.status, list_salaries[i].status);
			break;
		}
	}
	pthread_exit(NULL);
}

void *satisfaction(void *a) {
	for (int i = 0; i < FILE_LINE_COUNT; i++) {
		if (!strncmp(list_satisfaction[i].emp_id, employee_info.emp_id, 10)) {
			strcpy(satisfaction_search_result.emp_id, list_satisfaction[i].emp_id);
			strcpy(satisfaction_search_result.satisfaction_level, list_satisfaction[i].satisfaction_level);
			strcpy(satisfaction_search_result.number_projects, list_satisfaction[i].number_projects);
			strcpy(satisfaction_search_result.avg_monthly_hours, list_satisfaction[i].avg_monthly_hours);
			strcpy(satisfaction_search_result.years_at_company, list_satisfaction[i].years_at_company);
			strcpy(satisfaction_search_result.work_accidents, list_satisfaction[i].work_accidents);
			strcpy(satisfaction_search_result.promotions_last_5_years, list_satisfaction[i].promotions_last_5_years);
			break;
		}
	}
	pthread_exit(NULL);
}

int server(int sock) {
	pthread_t salaries_thread, satisfaction_thread;
	
	if (load_id_name() < 0) puts("error ID");
	if (load_salaries() < 0) puts("error SALARY");
	if (load_satisfaction() < 0) puts("error SATISFACTION");
	
	Query q;
	while(1) {
		strcpy(q.employee_name, "");
		strcpy(q.job_title, "");
		strcpy(q.status, "");
		
		puts("waiting...");
		recv(sock, q.employee_name, 75, 0);
		recv(sock, q.job_title, 75, 0);
		recv(sock, q.status, 75, 0);
		
		// if none of the input fields were empty
		if (strncmp(q.status, "", 3) && strncmp(q.employee_name, "", 3) && strncmp(q.job_title, "", 3)) {
			strcpy(employee_info.emp_id, "");
			strcpy(employee_info.emp_name, "");
			
			strcpy(salaries_search_result.emp_id, "");
			strcpy(salaries_search_result.job_title, "");
			strcpy(salaries_search_result.base_pay, "");
			strcpy(salaries_search_result.overtime_pay, "");
			strcpy(salaries_search_result.benefit, "");
			strcpy(salaries_search_result.status, "");
			
			strcpy(satisfaction_search_result.emp_id, "");
			strcpy(satisfaction_search_result.satisfaction_level, "");
			strcpy(satisfaction_search_result.number_projects, "");
			strcpy(satisfaction_search_result.avg_monthly_hours, "");
			strcpy(satisfaction_search_result.years_at_company, "");
			strcpy(satisfaction_search_result.work_accidents, "");
			strcpy(satisfaction_search_result.promotions_last_5_years, "");
			
			for (int i = 0; i < FILE_LINE_COUNT; i++) {
				// confirm if can do if (cond) instead of if (cond != null)
				if ((strcasestr(list_id_name[i].emp_name, q.employee_name) != NULL) && ((strcasestr(list_salaries[i].job_title, q.job_title) != NULL)) && ((strcasestr(list_salaries[i].status, q.status) != NULL))) {
					strcpy(employee_info.emp_id, list_id_name[i].emp_id);
					strcpy(employee_info.emp_name, list_id_name[i].emp_name);
					break;
				}
			}
			
			printf("%s\n%s\n%s\n\n", q.employee_name, q.job_title, q.status);
			
			pthread_create(&salaries_thread, NULL, salaries, (void *)&salaries_thread);
			pthread_create(&satisfaction_thread, NULL, satisfaction, (void *)&satisfaction_thread);
			pthread_join(salaries_thread, NULL);
			pthread_join(satisfaction_thread, NULL);
			
			char out[INFO_SIZE];
			if (!strncmp(employee_info.emp_id, "", 4)) send(sock, "no", INFO_SIZE, 0);
			else {
				sprintf(out, "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", employee_info.emp_id, employee_info.emp_name, 
					salaries_search_result.job_title, salaries_search_result.base_pay, salaries_search_result.overtime_pay,
					salaries_search_result.benefit, salaries_search_result.status, satisfaction_search_result.satisfaction_level,
					satisfaction_search_result.number_projects, satisfaction_search_result.avg_monthly_hours, satisfaction_search_result.years_at_company,
					satisfaction_search_result.work_accidents, satisfaction_search_result.promotions_last_5_years);
				send(sock, out, INFO_SIZE, 0);
			}
		} 
		else break;
	}
	puts("server exited");
	return 0;
}

			