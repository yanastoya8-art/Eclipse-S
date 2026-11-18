# Audio filtering architecture

- Verified timetable and native-language schedule providers must load independently of the title-level dub index; an unrelated metadata failure must not block their rows or cached schedules.
- Catalog audio lookups run in the background and publish completed evidence on the main actor; retained catalog snapshots are re-filtered without admitting unverified titles.
- Use CatalogNativeAudioPolicy for both catalog native-audio eligibility and skipping unnecessary dub lookups so those decisions cannot diverge.
