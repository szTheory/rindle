# GCS Session URI Log Hygiene

`session_uri` is a bearer credential for resumable uploads. Treat it like a secret: do not print it in logs, error metadata, or translated crash output.

As a defense-in-depth measure, add a logger translator that rewrites any `:session_uri` metadata before the event is formatted:

```elixir
Logger.add_translator(fn
  min_level, level, kind, message ->
    case message do
      {report, metadata} when is_list(metadata) ->
        filtered =
          Keyword.update(metadata, :session_uri, nil, fn _value -> "[REDACTED]" end)

        Logger.Translator.translate(min_level, level, kind, {report, filtered})

      other ->
        Logger.Translator.translate(min_level, level, kind, other)
    end
end)
```

If your logger pipeline normalizes metadata earlier, an equivalent metadata-filter step is acceptable as long as `:session_uri` never leaves the process in raw form.

This is an interim Phase 38 note only. Full GCS onboarding, bucket wiring, and broader resumable operations guidance remain Phase 41 work.
