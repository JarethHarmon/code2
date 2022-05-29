#ifndef PIPES_H
#define PIPES_H
#include "manager.h"

#define MANAGER_READER "./ManagerReader.o"
#define READER_ASSISTANT "./ReaderAssistant.o"
#define READER_SIGNAL "./ReaderSignal.o"

#define IP "127.0.0.1"
#define PORT 8081
#define BUFFER_SIZE 1024
#define QUEUE_SIZE 100
#define INFO_SIZE 1288

#define MAX_LINE_LENGTH 256
#define FILE_LINE_COUNT 148649
#define HISTORY_SIZE 10

typedef struct Query {
	int check;
	char employee_name[75];
	char job_title[75];
	char status[75];
} Query;

void make_fifos();

int open_write_pipe_manager_reader();
int open_read_pipe_manager_reader();
int open_write_pipe_reader_assistant();
int open_read_pipe_reader_assistant();
int open_write_signal_pipe_reader_assistant();
int open_read_signal_pipe_reader_assistant();

void manager_send_query(Query q, int fd);
void assistant_signal_reader(int fd);
int assistant_receive_query(Query *q, int fd);

int reader();
int assistant(char ip[24]);
int terminal(char output[1288], int history);

#endif