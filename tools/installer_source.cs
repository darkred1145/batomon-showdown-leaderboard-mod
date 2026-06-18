using System;
using System.IO;
using Microsoft.Win32;

public class Installer
{
    public static void Main()
    {
        string exeDir = Path.GetDirectoryName(System.Reflection.Assembly.GetExecutingAssembly().Location);
        string modDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
            "Batomon Showdown Leaderboard"
        );
        string pckSource = Path.Combine(exeDir, "batomon_showdown.pck");

        Console.WriteLine("=== Batomon Showdown - Leaderboard Mod Installer ===");
        Console.WriteLine("");

        string steamDir = FindGameDir();
        if (steamDir == null)
        {
            Console.WriteLine("ERROR: Could not find Batomon Showdown.");
            Console.WriteLine("Make sure it's installed on Steam.");
            Console.Write("Press Enter to exit...");
            Console.ReadLine();
            return;
        }

        Console.WriteLine("Found game at: " + steamDir);
        Console.WriteLine("Installing to: " + modDir);
        Directory.CreateDirectory(modDir);

        Console.WriteLine("Copying game files...");
        File.Copy(Path.Combine(steamDir, "batomon_showdown.exe"), Path.Combine(modDir, "batomon_showdown.exe"), true);
        File.Copy(Path.Combine(steamDir, "steam_api64.dll"), Path.Combine(modDir, "steam_api64.dll"), true);

        string steamDll = Path.Combine(steamDir, "libgodotsteam.windows.template_release.x86_64.dll");
        if (File.Exists(steamDll))
            File.Copy(steamDll, Path.Combine(modDir, "libgodotsteam.windows.template_release.x86_64.dll"), true);

        Console.WriteLine("Installing modded PCK...");
        File.Copy(pckSource, Path.Combine(modDir, "batomon_showdown.pck"), true);

        Console.WriteLine("Installing launcher...");
        string launcherSource = Path.Combine(exeDir, "Leaderboard Mod Launcher.exe");
        if (File.Exists(launcherSource))
            File.Copy(launcherSource, Path.Combine(modDir, "Leaderboard Mod Launcher.exe"), true);

        Console.WriteLine("");
        Console.WriteLine("Done! Mod installed to:");
        Console.WriteLine("  " + modDir);
        Console.WriteLine("Run 'Leaderboard Mod Launcher.exe' to play.");
        Console.WriteLine("");
        Console.Write("Press Enter to exit...");
        Console.ReadLine();
    }

    static string FindGameDir()
    {
        // Check common Steam install paths
        string[] candidates = new string[]
        {
            @"C:\Program Files (x86)\Steam\steamapps\common\Batomon Showdown Demo",
            @"C:\Program Files\Steam\steamapps\common\Batomon Showdown Demo",
        };

        foreach (string p in candidates)
        {
            if (File.Exists(Path.Combine(p, "batomon_showdown.exe")))
                return p;
        }

        // Try registry to find Steam install
        try
        {
            string steamPath = Registry.GetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Valve\Steam", "InstallPath", "") as string;
            if (string.IsNullOrEmpty(steamPath))
                steamPath = Registry.GetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\Valve\Steam", "InstallPath", "") as string;

            if (!string.IsNullOrEmpty(steamPath))
            {
                // Check main steamapps
                string main = Path.Combine(steamPath, "steamapps", "common", "Batomon Showdown Demo");
                if (File.Exists(Path.Combine(main, "batomon_showdown.exe")))
                    return main;

                // Check libraryfolders.vdf for additional libraries
                string vdfPath = Path.Combine(steamPath, "steamapps", "libraryfolders.vdf");
                if (File.Exists(vdfPath))
                {
                    string vdf = File.ReadAllText(vdfPath);
                    var matches = System.Text.RegularExpressions.Regex.Matches(vdf, "\"path\"\\s+\"([^\"]+)\"");
                    foreach (System.Text.RegularExpressions.Match m in matches)
                    {
                        string lib = m.Groups[1].Value.Replace("\\\\", "\\");
                        string testPath = Path.Combine(lib, "steamapps", "common", "Batomon Showdown Demo");
                        if (File.Exists(Path.Combine(testPath, "batomon_showdown.exe")))
                            return testPath;
                    }
                }
            }
        }
        catch { }

        return null;
    }
}
