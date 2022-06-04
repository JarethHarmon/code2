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
	private Dictionary<string, List<(string, string, DateTime, long)>> files = new Dictionary<string, List<(string, string, DateTime, long)>>();
	
	public void ScanDirectories(string path, bool recursive) {
		var now = DateTime.Now;
		var di = new System.IO.DirectoryInfo(@path);
		int image_count = ScanDirectories(di, recursive);
		GD.Print(path, "\n\tfound ", image_count, " images in ", (DateTime.Now-now).Milliseconds, " milliseconds\n");
	}
	
	private int ScanDirectories(System.IO.DirectoryInfo dir, bool recursive) {
		int image_count = 0;
		try {
			var fs = new List<(string, string, DateTime, long)>();
			foreach (System.IO.FileInfo f in dir.GetFiles()) {
				if (supported_extensions.Contains(f.Extension.ToUpperInvariant())) {
					fs.Add((f.Name, f.Extension, f.CreationTimeUtc, f.Length)); 
					image_count++;
				}
			}
			
			files[dir.FullName.Replace("\\", "/")] = fs;
			if (!recursive) return image_count;
			
			var enumerated_directory = dir.EnumerateDirectories();
			folders.Add(enumerated_directory);
			foreach (System.IO.DirectoryInfo d in enumerated_directory) {
				if (!d.FullName.Contains(" ")) { // U+00A0
					foreach (string bl in blacklisted_folders) if (d.FullName.Contains(bl)) continue;
					image_count += ScanDirectories(d, recursive);
				}
			}
		} catch (Exception ex) { GD.Print(dir.FullName, "\n", ex); return image_count; }
		return image_count;
	}
	
	public string[] GetImages() {
		var images = new List<string>();
		foreach (string folder in files.Keys.ToArray())
			foreach ((string, string, DateTime, long) image in files[folder])
				images.Add(folder + "/" + image.Item1);
		return images.ToArray();
	}
	
	public void Clear() {
		folders.Clear();
		files.Clear();
	}
	
}
