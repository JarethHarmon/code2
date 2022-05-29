//=================================================================================================
//	Jareth Harmon
//		>> a program that performs basic postfix calculations on integers
//=================================================================================================

// TODO: more error checking, support for BigInteger

import java.util.*;

public class PostFixCalc
{
	private static HashMap<String, Integer> memory = new HashMap<String, Integer>();
	
	private static boolean isNumeric(String s)
	{
		try { int x = Integer.parseInt(s); }
		catch (NumberFormatException nfe) { return false; }
		return true;
	}
	
	private static int factorial(int n)
	{
		if (n == 0) return 1;
		else return (n * factorial(n-1));
	}

	private void evaluate(String[] tokens)
	{
		try
		{
			boolean isAssignment = false;
			int startPosition = 0;
			Stack<Integer> stack = new Stack<Integer>();
			
			if (tokens.length > 1)
			{
				if (tokens[1].equals("="))
				{
					startPosition = 2;
					isAssignment = true;
				}
			}
			
			if (tokens[0].equals("var")) { System.out.println(memory); return; }
			else if (tokens[0].equals("quit")) { System.exit(0); return; }
			else if (tokens[0].equals("clear")) { memory.clear(); return; }
			else if (tokens[0].equals("delete")) { memory.remove(tokens[1]); return; }
			
			for (int i = startPosition; i < tokens.length; i++)
			{
				String token = tokens[i];
				// System.out.println(token);
				
				if (memory.containsKey(token)) stack.push(memory.get(token));
				if (isNumeric(token)) stack.push(Integer.parseInt(token));
				else if (token.equals("!")) stack.push(factorial(stack.pop()));
				else if (token.equals("+")) stack.push(stack.pop() + stack.pop());
				else if (token.equals("-"))
				{
					int a = stack.pop(); 
					int b = stack.pop();
					stack.push(b - a);
				}
				else if (token.equals("*")) stack.push(stack.pop() * stack.pop());
				else if (token.equals("/"))
				{
					int a = stack.pop(); 
					int b = stack.pop();
					stack.push(b / a);
				}
				else if (token.equals("^"))
				{
					int a = stack.pop(); 
					int b = stack.pop();
					stack.push((int)Math.pow(b,a));
				}
			}
			
			if (isAssignment) memory.put(tokens[0], stack.peek());
			if (stack.size() == 1) if (!stack.isEmpty()) System.out.println(stack.pop());
			else System.out.println("Error, not enough operands or operators.");
		}
		catch (Exception ex) { System.out.println(ex); }		
	}
	
	public static void main(String[] args)
	{
		PostFixCalc pfc = new PostFixCalc();
		Scanner scan = new Scanner(System.in);
		//System.out.printf("\tvar : prints current memory hashmap\n\tclear : clears current memory hashmap\n\tdelete __ : removes the specified token from the memory hashmap\n\texit : exits the program\n\tpostfix calculation : 7 8 *		9 8 + 7 * 2 ^    etc\n");
		System.out.printf("\tquit : exits program\n\tpostfix order : 8 7 *   ||   8 7 * 14 + 2 ^\n\tsupports : ! + - * ^ /\n");
		while (true)
		{
			try
			{
				System.out.print("> ");
				String input = scan.nextLine();
				String[] tokens = input.split(" ");
				pfc.evaluate(tokens);
			}
			catch (Exception ex) { System.out.println("Error"); }
		}
	}
}