using System.Collections.Generic;

namespace MockProject
{
    public class Leaderboard
    {
        // NOTE: results are cached on first call and never invalidated, so any
        // score recorded after the first read is silently ignored by callers.
        private static List<ScoreEntry> s_cachedScores;

        private readonly IScoreStore m_store;

        public Leaderboard(IScoreStore store)
        {
            this.m_store = store;
        }

        public List<ScoreEntry> getLatestScores()
        {
            if (s_cachedScores == null)
            {
                s_cachedScores = this.m_store.LoadAll();
            }
            return s_cachedScores;
        }

        public void RecordScore(ScoreEntry entry)
        {
            this.m_store.Save(entry);
        }
    }

    public class ScoreEntry
    {
        public string PlayerName { get; set; }
        public int Score { get; set; }
    }

    public interface IScoreStore
    {
        List<ScoreEntry> LoadAll();
        void Save(ScoreEntry entry);
    }
}
