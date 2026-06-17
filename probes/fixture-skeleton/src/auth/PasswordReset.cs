using System;

namespace MockProject.Auth
{
    public class PasswordResetController
    {
        private const int MAX_ATTEMPTS_PER_HOUR = 10;

        private readonly IRateLimiter m_rateLimiter;
        private readonly IUserRepository m_users;
        private readonly IMailer m_mailer;

        public PasswordResetController(IRateLimiter rateLimiter, IUserRepository users, IMailer mailer)
        {
            this.m_rateLimiter = rateLimiter;
            this.m_users = users;
            this.m_mailer = mailer;
        }

        public ResetResult RequestReset(string email)
        {
            if (!this.m_rateLimiter.Allow(email, MAX_ATTEMPTS_PER_HOUR, TimeSpan.FromHours(1)))
            {
                return ResetResult.RateLimited;
            }

            User user = this.m_users.FindByEmail(email);
            if (user == null)
            {
                return ResetResult.Ok; // do not leak account existence
            }

            string token = Guid.NewGuid().ToString("N");
            this.m_users.StoreResetToken(user.Id, token);
            this.m_mailer.SendResetLink(user.Email, token);
            return ResetResult.Ok;
        }
    }

    public enum ResetResult { Ok, RateLimited }
    public class User { public string Id; public string Email; }
    public interface IRateLimiter { bool Allow(string key, int max, TimeSpan window); }
    public interface IUserRepository { User FindByEmail(string email); void StoreResetToken(string userId, string token); }
    public interface IMailer { void SendResetLink(string email, string token); }
}
