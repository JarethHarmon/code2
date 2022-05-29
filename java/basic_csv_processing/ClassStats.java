//=================================================================================================
//	Jareth Harmon
//		>> program that performs basic csv processing 
//=================================================================================================

import java.util.*;
import java.io.*;

public class ClassStats
{
	private int rowLength = 0;
	private double totalPoints = 0.0;
	private String[][] classStorage;
	
	// how to run the program
	private void usage() { System.out.println("USAGE MESSAGE"); }
	
	// how to use the program
	private void help() { System.out.print("\tAccepted commands:\n\t  exit\n\t  help\n\t  roll\n\t  search [partialName]\n\t  assignments\n\t  report\n\t  student [student name]\n\t  assignment [assignment name]\n"); }
	
	private String grade(double percentage) 
	{
		if (percentage < 0.6) return "F";
		else if (percentage < 0.7) return "D";
		else if (percentage < 0.8) return "C";
		else if (percentage < 0.9) return "B";
		else return "A";
	}
	
	// prints each students name, totalPoints, and letterGrade
	private void roll()
	{
		System.out.printf("\t%-15s%-15s%10s%10s\n", "First Name", "Last Name", "Points", "Grade");
		System.out.printf("\t%-15s%-15s%10s%10s\n", "----------", "---------", "------", "-----");
		
		for (int i = 2; i < classStorage.length; i++)
		{
			// print first and last name
			System.out.printf("\t%-15s%-15s", classStorage[i][0], classStorage[i][1]);
			double score = 0.0;
			for (int j = 2; j < classStorage[i].length; j++) 
				score += Double.parseDouble(classStorage[i][j]);
			double percentage = score/totalPoints;
			String grade = grade(percentage);
			System.out.printf("%10.1f%10s\n", score, grade);
		}
	}
	
	// maybe find a way to call roll from search instead (will require a different setup for roll)
	
	// checks all firstNames and lastNames to see if they contain the substring <partialName>, 
	private void search(String partialName)
	{
		System.out.printf("\t%-15s%-15s%10s%10s\n", "First Name", "Last Name", "Points", "Grade");
		System.out.printf("\t%-15s%-15s%10s%10s\n", "----------", "---------", "------", "-----");
		
		for (int i = 2; i < classStorage.length; i++)
		{
			if (classStorage[i][0].toLowerCase().contains(partialName.toLowerCase()) || classStorage[i][1].toLowerCase().contains(partialName.toLowerCase()))
			{
				System.out.printf("\t%-15s%-15s", classStorage[i][0], classStorage[i][1]);
				double score = 0.0;
				for (int j = 2; j < classStorage[i].length; j++) 
					score += Double.parseDouble(classStorage[i][j]);
				double percentage = score/totalPoints;
				String grade = grade(percentage);
				System.out.printf("%10.1f%10s\n", score, grade);
			}
		}		
	}
	
	// prints a list of all assignments and their possible points
	private void assignments() 
	{
		System.out.printf("\t%-20s%20s\n", "Assignment Name", "Points Possible");
		System.out.printf("\t%-20s%20s\n", "---------------", "---------------");
		
		for (int i = 2; i < classStorage[0].length; i++)
			System.out.printf("\t%-20s%20s\n", classStorage[0][i], classStorage[1][i]);	
	}
	
	private void assignmentsStudent(int row) 
	{
		System.out.printf("\t%-20s%20s%20s\n", "Assignment Name", "Points Received", "Points Possible");
		System.out.printf("\t%-20s%20s%20s\n", "---------------", "---------------", "---------------");
		
		for (int i = 2; i < classStorage[0].length; i++)
			System.out.printf("\t%-20s%20s%20s\n", classStorage[0][i], classStorage[row][i], classStorage[1][i]);	
	}
	
	private double calcScore(int row)
	{
		double score = 0.0;
		for (int i = 2; i < rowLength; i++) 
			score += Double.parseDouble(classStorage[row][i]);
		return score;
	}
	
	//
	private void studentReport(String[] studentName)
	{
		String fName = studentName[1].toLowerCase();
		String lName = studentName[2].toLowerCase();
		
		for (int i = 2; i < classStorage.length; i++)
		{
			if (classStorage[i][0].toLowerCase().equals(fName) && classStorage[i][1].toLowerCase().equals(lName))
			{
				System.out.println("  Name: " + classStorage[i][0] + " " + classStorage[i][1]);
				System.out.println("  Assignments:");
				assignmentsStudent(i);
				double score = calcScore(i);
				double percentage = score/totalPoints;
				System.out.printf("  Total Points: %1.1f / %1.1f\n", score, totalPoints); 
				System.out.println("  Grade: " + grade(percentage)); 
			}
		}
	}
	
	//
	private void assignmentReport(String[] assignmentName)
	{
		String aName = "";
		for (int i = 1; i < assignmentName.length-1; i++) 
			aName += assignmentName[i] + " ";
		aName += assignmentName[assignmentName.length-1];
		aName = aName.toLowerCase();
		
		for (int i = 2; i < rowLength; i++)
		{
			if (classStorage[0][i].toLowerCase().equals(aName))
			{
				System.out.printf("\t%-20s%10s\n", classStorage[0][i], classStorage[1][i]);
				
				double maxScore = Double.parseDouble(classStorage[1][i]);
				double low = Double.parseDouble(classStorage[2][i]);
				double high = 0.0;
				
				double total = 0.0;
				double count = 0.0;
				
				// A,B,C,D,F
				int[] numGrades = {0,0,0,0,0};
				
				for (int row = 2; row < classStorage.length; row++)
				{
					double score = Double.parseDouble(classStorage[row][i]);
					if (score < low) low = score;
					else if (score > high) high = score;
					count += 1.0;
					total += score;
					
					if (grade(score/maxScore).equals("A")) numGrades[0]++;
					else if (grade(score/maxScore).equals("B")) numGrades[1]++;
					else if (grade(score/maxScore).equals("C")) numGrades[2]++;
					else if (grade(score/maxScore).equals("D")) numGrades[3]++;
					else numGrades[4]++;
				}
				System.out.printf("\t%s%1.1f%20s%1.1f%20s%1.1f\n", "Low: ", low, "High: ", high, "Average: ", total/count);
				System.out.printf("\t%s%d%10s%d%10s%d%10s%d%10s%d\n", "A: ", numGrades[0], "B: ", numGrades[1], "C: ", numGrades[2], "D: ", numGrades[3], "F: ", numGrades[4]);
			}
		}		
	}
	
	//
	private void report() 
	{
		double low = calcScore(2);
		double high = 0.0;
		double total = 0.0;
		double count = 0.0;
		
		// A,B,C,D,F
		int[] numGrades = {0,0,0,0,0};
		
		for (int row = 2; row < classStorage.length; row++)
		{
			double score = calcScore(row);
			if (score < low) low = score;
			else if (score > high) high = score;
			total += score;
			count += 1.0;
			
			if (grade(score/totalPoints).equals("A")) numGrades[0]++;
			else if (grade(score/totalPoints).equals("B")) numGrades[1]++;
			else if (grade(score/totalPoints).equals("C")) numGrades[2]++;
			else if (grade(score/totalPoints).equals("D")) numGrades[3]++;
			else numGrades[4]++;
		}
		System.out.printf("\t%s%1.1f%20s%1.1f%20s%1.1f\n", "Low: ", low, "High: ", high, "Average: ", total/count);
		System.out.printf("\t%s%d%10s%d%10s%d%10s%d%10s%d\n", "A: ", numGrades[0], "B: ", numGrades[1], "C: ", numGrades[2], "D: ", numGrades[3], "F: ", numGrades[4]);
	}
	
	public static void main(String[] args)
	{
		ClassStats cs = new ClassStats();
		if (args.length < 1) { cs.usage(); return; }
		
		try
		{
			Scanner scan = new Scanner(new File(args[0]));
			ArrayList<String> tempStorage = new ArrayList<>();
			while (scan.hasNext())
			{
				String line = scan.nextLine();
				if (!line.equals("\n") && !line.equals("") && !line.equals(" ")) tempStorage.add(line); // replace with regex ?
			}
			scan.close();
			
			String[] row1 = tempStorage.get(1).split(",");
			cs.rowLength = row1.length;
			
			cs.classStorage = new String[tempStorage.size()][cs.rowLength];
			for (int i = 0; i < tempStorage.size(); i++) 
				cs.classStorage[i] = tempStorage.get(i).split(",");
			
			// rewrite above to directly load data into classStorage (ie without going through tempStorage)
			
			cs.totalPoints = cs.calcScore(1);
			
			scan = new Scanner(System.in);
			while (true)
			{
				System.out.print("\n> ");
				String input = scan.nextLine();
				String[] tokens = input.split(" ");
				if (tokens[0].equals("exit")) break;
				else if (tokens[0].equals("help")) cs.help();
				else if (tokens[0].equals("roll")) cs.roll();
				else if (tokens[0].equals("search")) cs.search(tokens[1]);
				else if (tokens[0].equals("assignments")) cs.assignments();
				else if (tokens[0].equals("student")) cs.studentReport(tokens);
				else if (tokens[0].equals("assignment")) cs.assignmentReport(tokens);
				else if (tokens[0].equals("report")) cs.report();
				else cs.help();
			}
			scan.close();			
		}
		catch (FileNotFoundException fnfe) { System.out.println("Please ensure the file you entered exists.");  }
		catch (Exception ex) { System.out.println(ex); cs.usage(); }
	}
}
