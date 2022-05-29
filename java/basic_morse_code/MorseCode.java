//=================================================================================================
//	Jareth Harmon
//		>> a program that performs basic encoding to and decoding from morse code
//=================================================================================================

import java.util.*;

public class MorseCode
{
	private static final Map<String, String> encode;
	private static final Map<String, String> decode;
	static {
		encode = new HashMap<String, String>() {{
			put("A", ".-"); put("B", "-..."); put("C", "-.-."); put("D", "-..");		
			put("E", "."); put("F", "..-."); put("G", "--."); put("H", "...."); 
			put("I", ".."); put("J", ".---"); put("K", "-.-"); put("L", ".-.."); 
			put("M", "--"); put("N", "-."); put("O", "---"); put("P", ".--."); 
			put("Q", "--.-"); put("R", ".-."); put("S", "..."); put("T", "-"); 
			put("U", "..-"); put("V", "...-"); put("W", ".--"); put("X", "-..-"); 
			put("Y", "-.--"); put("Z", "--.."); put("1", ".----"); put("2", "..---");
			put("3", "...--"); put("4", "....-"); put("5", "....."); put("6", "-....");
			put("7", "--..."); put("8", "---.."); put("9", "----."); put("0", "-----");
			put(".", ".-..."); put("?", ".-..-"); put("!", ".-.-."); put(" ", ".-.--");
		}};
		decode = new HashMap<String, String>() {{
			put(".-", "A"); put("-...", "B"); put("-.-.", "C"); put("-..", "D");
			put(".", "E"); put("..-.", "F"); put("--.", "G"); put("....", "H"); 
			put("..", "I"); put(".---", "J"); put("-.-", "K"); put(".-..", "L"); 
			put("--", "M"); put("-.", "N"); put("---", "O"); put(".--.", "P"); 
			put("--.-", "Q"); put(".-.", "R"); put("...", "S"); put("-", "T"); 
			put("..-", "U"); put("...-", "V"); put(".--", "W"); put("-..-", "X"); 
			put("-.--", "Y"); put("--..", "Z"); put(".----", "1"); put("..---", "2");
			put("...--", "3"); put("....-", "4"); put(".....", "5"); put("-....", "6");
			put("--...", "7"); put("---..", "8"); put("----.", "9"); put("-----", "0");
			put(".-...", "."); put(".-..-", "?"); put(".-.-.", "!"); put(".-.--", " ");
		}};
	}
	
	// prints the usage statement to the console
	private static void usage()
	{ 
		System.out.println("usage:\n\tencode: java MorseCode -e < inputFile > outputFile\n\tdecode: java MorseCode -d < inputFile > outputFile"); 
	}
	
	// encodes the user-provided input and prints it to the user-provided output
	private static void encode()
	{
		Scanner scan = new Scanner(System.in);
		String s = scan.nextLine();
		scan.close();
		String encoded = "";

		for (int i = 0; i < s.length()-1; i++)
		{ 
			String tmp = "" + s.charAt(i);
			encoded += encode.get(tmp.toUpperCase()) + ",";
		}
		String tmp = "" + s.charAt(s.length()-1);
		encoded += encode.get(tmp.toUpperCase());
		
		System.out.print(encoded);
	}
	
	// decodes the user-provided input and prints it to the user-provided output
	private static void decode()
	{
		Scanner scan = new Scanner(System.in);
		String s = scan.nextLine();
		scan.close();
		String decoded = "";
		String[] sections = s.split(",");
		
		for (int i = 0; i < sections.length; i++)
		{
			decoded += decode.get(sections[i]);
		}
		
		System.out.print(decoded);
	}
	
	// does a basic check of the user input and calls the relevant method
	public static void main(String[] args)
	{
		if (args.length < 1) usage();
		else
		{
			if (args[0].equals("-e")) encode();
			else if (args[0].equals("-d")) decode();
			else usage();
		}
	}
}