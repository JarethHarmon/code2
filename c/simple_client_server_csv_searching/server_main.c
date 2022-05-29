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

int print_public_ip() {
	FILE *fptr = fopen("ip.txt", "w");
	if (fptr == NULL) return 1;
	fclose(fptr);
	
	system("ip address > ./ip.txt");
	fptr = fopen("ip.txt", "r");
	if (fptr == NULL) return 1;
	
	fseek(fptr, 0, SEEK_END);
	long file_size = ftell(fptr);
	fseek(fptr, 0, SEEK_SET);
	
	char *ip_file;
	ip_file = malloc(file_size * sizeof(char));
	
	int one = 0, two = 0;
	fread(ip_file, 1, file_size, fptr);
	fclose(fptr);
	
	char *token;
	token = strtok(ip_file, " /\t\n");
	while (token != NULL) {
		if (two) {
			puts("Please enter this IP into the client terminal: ");
			puts(token);
			break;
		}
		if (!strncmp(token, "inet", 10)) {
			if (one) two = 1;
			else one = 1;
		}
		token = strtok(NULL, " /\t\n");
	}
	free(ip_file);
	return 0;
}

int main() {
	print_public_ip();
	
	int server_fd, sock, check;
	struct sockaddr_in address;
	int addrlen = sizeof(address);
	char buffer[BUFFER_SIZE] = {0};
	
	if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
		perror("Server socket creation failed: ");
		return 1;
	}
	
	address.sin_family = AF_INET;
	address.sin_addr.s_addr = INADDR_ANY;
	address.sin_port = htons(PORT);
	
	if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &(int){1}, sizeof(int)) < 0) {
		perror("Server setsockopt(SO_REUSEADDR) failed: ");
		return 1;
	}
	
	if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
		perror("Server socket binding failed: ");
		return 1;
	}
	
	if (listen(server_fd, 3) < 0) {
		perror("Server socket listen failed: ");
		return 1;
	}
	
	if ((sock = accept(server_fd, (struct sockaddr *)&address, &addrlen)) < 0) {
		perror("Server socket accept failed: ");
		return 1;
	}
	
	server(sock);
	
	close(sock);
	puts("server main exited");
	return 0;
}