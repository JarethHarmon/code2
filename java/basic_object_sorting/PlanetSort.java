//=================================================================================================
//	Jareth Harmon
//		>> basic object comparison and sorting (of planets in this case)
//=================================================================================================

import java.util.*;
import java.io.*;

public class PlanetSort
{
	private class Planet
	{
		private String planetName;
		private int yearDiscovered;
		private double mass;
		private double radius;
		private double orbitPeriod;
		
		public Planet(String n, int y, double m, double r, double o)
		{
			planetName = n;
			yearDiscovered = y;
			mass = m;
			radius = r;
			orbitPeriod = o;
		}
		
		public String toString() { return String.format("%-7s%18d%10.2f%11.2f%10.2f", planetName, yearDiscovered, mass, radius, orbitPeriod); }
	}

	private class PlanetNameComparator implements Comparator<Planet>
	{
		public int compare(Planet a, Planet b)
		{
			return a.planetName.compareToIgnoreCase(b.planetName);
		}
	}

	private class PlanetYearDiscoveredComparator implements Comparator<Planet>
	{
		public int compare(Planet a, Planet b)
		{
			if (a.yearDiscovered < b.yearDiscovered) return -1;
			else if (a.yearDiscovered > b.yearDiscovered) return 1;
			else return 0;
		}
	}

	private class PlanetMassComparator implements Comparator<Planet>
	{
		public int compare(Planet a, Planet b)
		{
			if (a.mass < b.mass) return -1;
			else if (a.mass > b.mass) return 1;
			else return 0;
		}
	}

	private class PlanetRadiusComparator implements Comparator<Planet>
	{
		public int compare(Planet a, Planet b)
		{
			if (a.radius < b.radius) return -1;
			else if (a.radius > b.radius) return 1;
			else return 0;
		}
	}

	private class PlanetOrbitPeriodComparator implements Comparator<Planet>
	{
		public int compare(Planet a, Planet b)
		{
			if (a.orbitPeriod < b.orbitPeriod) return -1;
			else if (a.orbitPeriod > b.orbitPeriod) return 1;
			else return 0;
		}
	}

	private void input() 
	{
		System.out.println("Please use the correct command: planets_file.txt name || year || mass || radius || orbit");
	}
	
	private void sortPlanets(String arg1, ArrayList<Planet> planets)
	{
		if (arg1.equalsIgnoreCase("name")) Collections.sort(planets, new PlanetNameComparator());
		else if (arg1.equalsIgnoreCase("year")) Collections.sort(planets, new PlanetYearDiscoveredComparator());
		else if (arg1.equalsIgnoreCase("mass")) Collections.sort(planets, new PlanetMassComparator());
		else if (arg1.equalsIgnoreCase("radius")) Collections.sort(planets, new PlanetRadiusComparator());
		else if (arg1.equalsIgnoreCase("orbit")) Collections.sort(planets, new PlanetOrbitPeriodComparator());
		else System.out.println("Please use a correct input option: name || year || mass || radius || orbit");
	}
	
	private void addPlanet(String[] tokens, ArrayList<Planet> planets)
	{
		planets.add(new Planet(tokens[0], Integer.parseInt(tokens[1]), Double.parseDouble(tokens[2]), Double.parseDouble(tokens[3]), Double.parseDouble(tokens[4])));
	}
	
	public static void main(String[] args)
	{
		PlanetSort ps = new PlanetSort();
		if (args.length < 1) ps.input();
		else
		{
			ArrayList<Planet> planets = new ArrayList<>();
			try
			{
				Scanner scan = new Scanner(new File(args[0]));
				while (scan.hasNext())
				{
					String line = scan.nextLine();
					String[] tokens = line.split(",");
					if (tokens.length < 5) System.out.printf("\nincorrectly formatted input line: \"%s\"", line);
					else ps.addPlanet(tokens, planets);
				}
				scan.close();
				ps.sortPlanets(args[1], planets);
				System.out.printf("%nName\t   YearDiscovered      Mass\tRadius\tOrbitPeriod\n------------------------------------------------------------\n");
				for (int i = 0; i < planets.size(); i++) System.out.println(planets.get(i));
			}
			catch (FileNotFoundException fnfe) { System.out.println("Please ensure the file you entered exists."); }
			catch (ArrayIndexOutOfBoundsException aioobe) { ps.input(); }
		}			
	}
}
