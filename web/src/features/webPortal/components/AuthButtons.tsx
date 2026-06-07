import {
  authProviders,
  type AuthProviderId
} from "../model/syncSecurityPolicy";

function GitHubGlyph() {
  return (
    <svg aria-hidden="true" className="authGlyph" viewBox="0 0 24 24">
      <path d="M12 .5C5.7.5.6 5.6.6 11.9c0 5 3.3 9.3 7.9 10.8.6.1.8-.2.8-.6v-2c-3.2.7-3.9-1.4-3.9-1.4-.5-1.3-1.3-1.7-1.3-1.7-1-.7.1-.7.1-.7 1.1.1 1.8 1.2 1.8 1.2 1 1.7 2.7 1.2 3.3.9.1-.7.4-1.2.7-1.5-2.6-.3-5.3-1.3-5.3-5.7 0-1.3.5-2.3 1.2-3.1-.1-.3-.5-1.5.1-3 0 0 1-.3 3.2 1.2.9-.3 1.9-.4 2.9-.4s2 .1 2.9.4c2.2-1.5 3.2-1.2 3.2-1.2.6 1.5.2 2.7.1 3 .8.8 1.2 1.8 1.2 3.1 0 4.4-2.7 5.4-5.3 5.7.4.4.8 1.1.8 2.2v3.2c0 .3.2.7.8.6 4.6-1.5 7.9-5.8 7.9-10.8C23.4 5.6 18.3.5 12 .5z" />
    </svg>
  );
}

function GoogleGlyph() {
  return <span className="googleGlyph" aria-hidden="true">G</span>;
}

export function AuthButtons({
  onSelect
}: {
  onSelect: (provider: AuthProviderId) => void;
}) {
  return (
    <div className="authButtonStack">
      {authProviders.map((provider) => (
        <button
          className="authButton"
          key={provider.id}
          onClick={() => onSelect(provider.id)}
          type="button"
        >
          {provider.id === "github" ? <GitHubGlyph /> : <GoogleGlyph />}
          <span>{provider.label}</span>
        </button>
      ))}
    </div>
  );
}
