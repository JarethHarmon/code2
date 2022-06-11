using Godot;
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using Alphaleonis.Win32.Filesystem;

public class ImageScanner : Node
{
	public HashSet<string> supported_extensions = new HashSet<string>{".PNG", ".JPG", ".JPEG"};
	
	public List<string> blacklisted_folders = new List<string>{"System Volume Information", "$RECYCLE.BIN"};
	private List<IEnumerable<System.IO.DirectoryInfo>> folders = new List<IEnumerable<System.IO.DirectoryInfo>>();
	private Dictionary<string, List<(string, string, long, long)>> files = new Dictionary<string, List<(string, string, long, long)>>();
	
	public int ScanDirectories(string path, bool recursive) {
		var now = DateTime.Now;
		var di = new System.IO.DirectoryInfo(@path);
		int image_count = ScanDirectories(di, recursive);
		GD.Print("SCAN  (R=", (recursive)?"t":"f" + "):   ", path, "\t; found ", image_count, " images in ", (DateTime.Now-now).Milliseconds, " ms");
		return image_count;
	}
	
	private int ScanDirectories(System.IO.DirectoryInfo dir, bool recursive) {
		int image_count = 0;
		try {
			var fs = new List<(string, string, long, long)>();
			foreach (System.IO.FileInfo f in dir.GetFiles()) {
				if (supported_extensions.Contains(f.Extension.ToUpperInvariant())) {
					fs.Add((f.Name, f.Extension, f.CreationTimeUtc.Ticks, f.Length)); 
					image_count++;
				}
			}
			
			files[dir.FullName.Replace("\\", "/")] = fs;
			if (!recursive) return image_count;
			
			var enumerated_directory = dir.EnumerateDirectories();
			folders.Add(enumerated_directory);
			foreach (System.IO.DirectoryInfo d in enumerated_directory) {
				if (!d.FullName.Contains(" ")) { // U+00A0 (this symbol really breaks things for some reason)
					foreach (string bl in blacklisted_folders) if (d.FullName.Contains(bl)) continue;
					image_count += ScanDirectories(d, recursive);
				}
			}
		} catch (Exception ex) { GD.Print(dir.FullName, "\n", ex); return image_count; }
		return image_count;
	}
	
	// would use a fairly large amount of RAM on the upper ends (scanning millions of images for example)
	public List<(string, long, long)> GetImages() {
		var images = new List<(string, long, long)>();
		foreach (string folder in files.Keys.ToArray())
			foreach ((string, string, long, long) image in files[folder])
				images.Add((folder + "/" + image.Item1, image.Item3, image.Item4));
		Clear();
		return images;
	}
	
	public void Clear() {
		folders.Clear();
		files.Clear();
	}
	
}
