#ifndef SERVER_H
#define SERVER_H

typedef struct EmployeeInformation {
	char emp_id[99];
	char emp_name[99];
} EmployeeInformation;

typedef struct IDName {
	char emp_id[99];
	char emp_name[99];
} IDName;

typedef struct Salaries {
	char emp_id[99];
	char job_title[99];
	char base_pay[99];
	char overtime_pay[99];
	char benefit[99];
	char status[99];
} Salaries;

typedef struct Satisfaction {
	char emp_id[99];
	char satisfaction_level[99];
	char number_projects[99];
	char avg_monthly_hours[99];
	char years_at_company[99];
	char work_accidents[99];
	char promotions_last_5_years[99];
} Satisfaction;

int server();

#endif