alias HaruCore.{Repo, Accounts, Sites}
alias HaruCore.Accounts.User
alias HaruCore.Sites.Site
alias HaruCore.Analytics.Event

IO.puts("Seeding database...")

# Create dev user
{:ok, user} =
  case Repo.get_by(User, email: "dev@haru.local") do
    nil ->
      Accounts.register_user(%{
        email: "dev@haru.local",
        password: "devsecret123456"
      })

    existing ->
      {:ok, existing}
  end

IO.puts("User: #{user.email}")

# Create demo site
{:ok, site} =
  case Repo.get_by(Site, domain: "demo.haru.local") do
    nil ->
      Sites.create_site(%{
        name: "Demo Site",
        domain: "demo.haru.local",
        user_id: user.id
      })

    existing ->
      {:ok, existing}
  end

IO.puts("Site: #{site.name} (token: #{site.api_token})")

# Generate 200 events distributed over the last 24 hours
paths = ["/", "/blog", "/about", "/contact", "/pricing", "/docs", "/blog/elixir-otp", "/blog/phoenix-liveview"]
referrers = ["https://google.com", "https://twitter.com", "https://reddit.com", "", "", ""]
countries = ["US", "BR", "DE", "GB", "FR", "JP", "CA", "AU"]
ips = for i <- 1..50, do: "192.168.1.#{i}"

now = DateTime.utc_now()

events =
  for _i <- 1..200 do
    hours_ago = :rand.uniform(24)
    inserted_at = DateTime.add(now, -hours_ago * 3600 - :rand.uniform(3600), :second)
    ip = Enum.random(ips)
    ip_hash = :crypto.hash(:sha256, ip) |> Base.encode16(case: :lower)

    %{
      site_id: site.id,
      name: "pageview",
      path: Enum.random(paths),
      referrer: Enum.random(referrers),
      user_agent: "Mozilla/5.0 (Haru Seed)",
      screen_width: Enum.random([1280, 1440, 1920, 375, 414]),
      screen_height: Enum.random([720, 900, 1080, 812, 896]),
      country: Enum.random(countries),
      ip_hash: ip_hash,
      inserted_at: DateTime.truncate(inserted_at, :second)
    }
  end

{count, _} = Repo.insert_all(Event, events)
IO.puts("Inserted #{count} demo events")
IO.puts("\nDone! Login with dev@haru.local / devsecret123456")
IO.puts("Site API token: #{site.api_token}")
