import React from "react";

const COLOR_CTA_GREEN = "#2ECC71";

export function Homepage(): JSX.Element {
    return (
        <main className="homepage">
            <h1>Welcome</h1>
            <p>Track your scores, climb the leaderboard.</p>
            <button
                className="cta"
                style={{ backgroundColor: COLOR_CTA_GREEN, color: "#fff" }}
            >
                Get started
            </button>
        </main>
    );
}
