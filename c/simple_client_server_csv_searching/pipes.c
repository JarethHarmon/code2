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

#include "pipes.h"
#include "assistant.h"

struct Query queue[QUEUE_SIZE];
int start_index = 0, end_index = 0, empty = 1;


/* ----------------------------------------------------------------------------------------------------	*/

/* checks if the queue is empty and that the indices are valid */
// could rewrite to return empty instead, but it is more code overall
void check_queue() {
	if (start_index == end_index) empty = 1;
	else if (start_index > end_index) {
		empty = 1;
		start_index = end_index;
	} else empty = 0;
	
	if (end_index >= QUEUE_SIZE) end_index = 0;
	if (start_index >= QUEUE_SIZE) start_index = 0;
}

/* appends a query to the queue */
void append(Query q) {
	check_queue();
	
	queue[end_index].check = q.check;
	strcpy(queue[end_index].employee_name, q.employee_name);
	strcpy(queue[end_index].job_title, q.job_title);
	strcpy(queue[end_index].status, q.status);
	
	end_index++;
}

/* removes the first query from the queue and places it at the pointer address */
void pop_front(Query *q) {
	check_queue();
	
	q->check = queue[start_index].check;
	queue[start_index].check = -1;
	
	strcpy(q->employee_name, queue[start_index].employee_name);
	strcpy(queue[start_index].employee_name, "");
	
	strcpy(q->job_title, queue[start_index].job_title);
	strcpy(queue[start_index].job_title, "");
	
	strcpy(q->status, queue[start_index].status);
	strcpy(queue[start_index].status, "");
	
	start_index++;
}

/* ----------------------------------------------------------------------------------------------------	*/

/* creates the named pipes needed for ipc */
void make_fifos() {
	mkfifo(MANAGER_READER, 0666);
	mkfifo(READER_SIGNAL, 0666);
	mkfifo(READER_ASSISTANT, 0666);
}

/* opens the pipe between the manager and the reader for writing */
int open_write_pipe_manager_reader() {
	int fd;
	if ((fd = open(MANAGER_READER, O_WRONLY | O_CREAT)) < 0) {			// attempt to open or create the named pipe 'ManagerReader' in read/write mode
		perror("Failed to open ManagerReader pipe for writing: ");
		return -1;
	}
	return fd;
}

/* opens the pipe between the manager and the reader for reading */
/* non blocking so it can receive from manager while checking if assistant wants a query */
int open_read_pipe_manager_reader() {
	int fd;
	if ((fd = open(MANAGER_READER, O_RDONLY | O_NONBLOCK)) < 0) {		// attempt to open the named pipe 'ManagerReader' in non-blocking read mode
		perror("Failed to open ManagerReader pipe for reading: ");		
		return -1;
	}
	return fd;
}

/* opens the pipe between the reader and the assistant for writing */
int open_write_pipe_reader_assistant() {
	int fd;
	if ((fd = open(READER_ASSISTANT, O_WRONLY | O_CREAT)) < 0) {		// attempt to open or create the named pipe 'ReaderAssistant' in read/write mode
		perror("Failed to open ReaderAssistant pipe for writing: ");
		return -1;
	}
	return fd;
}

/* opens the pipe between the reader and assistant for reading */
int open_read_pipe_reader_assistant() {
	int fd;
	if ((fd = open(READER_ASSISTANT, O_RDONLY)) < 0) {					// attempt to open the named pipe 'ReaderAssistant' in read mode
		perror("Failed to open ReaderAssistant pipe for reading: ");
		return -1;
	}
	return fd;
}

/* opens the pipe for signaling that the assistant wants a query for writing */
int open_write_signal_pipe_reader_assistant() {
	int fd;
	if ((fd = open(READER_SIGNAL, O_WRONLY | O_CREAT)) < 0) {			// attempt to open or create the named pipe 'ReaderSignal' in read/write mode
		perror("Failed to open ReaderSignal pipe for writing: ");
		return -1;
	}
	return fd;
}

/* opens the pipe for signaling that the assistant wants a query for reading */
/* nonblocking so it can receive from manager and check if assistant wants a query */
int open_read_signal_pipe_reader_assistant() {
	int fd;
	if ((fd = open(READER_SIGNAL, O_RDONLY | O_NONBLOCK)) < 0) {		// attempt to open the named pipe 'ReaderSignal' in non-blocking read mode
		perror("Failed to open ReaderSignal pipe for reading: ");
		return -1;
	}
	return fd;
}

/* ----------------------------------------------------------------------------------------------------	*/

/* sends a query from the manager to the reader */
void manager_send_query(Query q, int fd) { write(fd, &q, sizeof(q)); }

/* sends the signal that the assistant is ready for a query to the reader */
void assistant_signal_reader(int fd) {
	int signal = 1;
	write(fd, &signal, sizeof(signal));
}

/* receives a query from the reader and stores it at the given pointer address */
int assistant_receive_query(Query *q, int fd) {
	q->check = -1;
	return read(fd, q, sizeof(*q));		// not (fd, &q, sizeof(q)) because q is already passed to this function as an address
}

/* connects to the server from the assistant */
int connect_to_server(char ip[24]) {
	int sock;
	struct sockaddr_in serv_addr;
	char buffer[BUFFER_SIZE] = {0};
	
	/* create the client socket (AF_INET = ipv4, SOCK_STREAM = tcp) */
	if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
		perror("Failed to create a socket for the client: ");
		return -1;
	}
	
	serv_addr.sin_family = AF_INET;
	serv_addr.sin_port = htons(PORT);
	
	/* check if the given IP is valid */
	if (inet_pton(AF_INET, ip, &serv_addr.sin_addr) <= 0) { 
		perror("Invalid address or address not supported: ");
		return -1;
	}
	
	/* attempt to connect to the server */
	if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
		perror("Client failed to connect to server: ");
		return -1;
	}
	
	return sock; 	// return the socket on successful connection
}

/* sends a query to the server */
int send_query_to_server(Query q, int sock) {
	if (send(sock, q.employee_name, 75, 0) < 0) return -1;
	if (send(sock, q.job_title, 75, 0) < 0) return -1;
	if (send(sock, q.status, 75, 0) < 0) return -1;
	return 0;
}

/* receives queries from the manager, appends them to a queue; gives a query to assistant when it signals that it wants one */
int reader() {
	int mana_fd, signal_fd, assi_fd, check_if_pipe_closed, signal;
	
	if ((mana_fd = open_read_pipe_manager_reader()) < 0) exit(1);
	if ((signal_fd = open_read_signal_pipe_reader_assistant()) < 0) exit(1);
	if ((assi_fd = open_write_pipe_reader_assistant()) < 0) exit(1);
	
	Query q;
	while(1) {
		q.check = -1;
		if (check_if_pipe_closed = read(mana_fd, &q, sizeof(q)) == 0) break;
		if (q.check > 0) append(q);		// if a query was read, append it to the queue
		
		check_queue();
		read(signal_fd, &signal, sizeof(signal));
		
		// if assistant signaled that it wants a query, pop the first one off the queue and send it to the assistant
		if (signal == 1 && !empty) {
			signal = 0;
			Query qq;
			qq.check = -1;
			pop_front(&qq);
			if (qq.check > 0) write(assi_fd, &qq, sizeof(qq));
		}
	}
	
	close(mana_fd);
	close(signal_fd);
	close(assi_fd);
	
	puts("reader exited");
	exit(0);	
}

int terminal(char output[INFO_SIZE], int history) {
	//char cmd[INFO_SIZE];
	//sprintf(cmd, "echo \"%s\"", output);
	if (history) printf("FROM HISTORY: ");
	else printf("FROM SERVER: ");
	puts(output); // printf("%s", output);
	//execlp("xterm", "xterm", "-hold", "-e", "bash", "-c", cmd, NULL);
}

int assistant(char ip[24]) {
	pid_t reader_pid;
	int signal_fd, reader_fd, check_if_pipe_closed, sock;
	char buffer[BUFFER_SIZE] = {0};
	
	if ((sock = connect_to_server(ip)) < 0) exit(1);
	if ((reader_pid = fork()) == 0) reader();
	if ((signal_fd = open_write_signal_pipe_reader_assistant()) < 0) exit(1);
	if ((reader_fd = open_read_pipe_reader_assistant()) < 0) exit(1);
	
	Query q;
	while(1) {
		assistant_signal_reader(signal_fd);
		q.check = -1;
		check_if_pipe_closed = assistant_receive_query(&q, reader_fd);
		if (check_if_pipe_closed == 0) break;
		
		if (q.check > 0) {
			if (read_from_history(q) == 0) continue; // read_from_history will call terminal if it is in history
			send_query_to_server(q, sock);
			
			char buf[INFO_SIZE];
			strcpy(buf, "");
			
			recv(sock, buf, INFO_SIZE, 0);
			if (strncmp(buf, "no", 5)) {
				//if (!fork()) terminal(buf, 0);
				terminal(buf, 0);
				write_to_history(q, buf);
			} else puts("Your query did not match any employees in the file.\n");
		}
	}
	wait(NULL); // wait for reader process to close
	
	close(signal_fd);
	close(reader_fd);
	close(sock);
	
	puts("assistant exited");
	exit(0);
}