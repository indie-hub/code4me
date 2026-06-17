using System;

namespace MockProject
{
    public static class ScoreFormatter
    {
        public static string Format(int score)
        {
            return "Score: " + score;
        }

        public static string FormatWithPlayer(string playerName, int score)
        {
            return playerName + " — " + "Score: " + score.ToString();
        }

        public static string FormatRank(int rank, int score)
        {
            return "#" + rank + " (" + score + " pts)";
        }
    }
}
