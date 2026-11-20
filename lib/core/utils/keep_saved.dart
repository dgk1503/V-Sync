/// Whether a refresh that came back [fresh] should be thrown away in favour of
/// what is already [saved].
///
/// VTOP does not say "I could not do that": a request it mishandled, a session
/// it half dropped or a menu it switched off all come back as a normal page with
/// nothing in it, which parses to an empty list. Replacing saved data with that
/// empty list is how a student's marks disappeared with no error at all.
///
/// So an empty answer never overwrites a non-empty one. The one case this
/// cannot serve, a student who genuinely lost every record, is not a case that
/// happens within a semester.
bool shouldKeepSaved({
  required List<Object?> fresh,
  required List<Object?> saved,
}) => fresh.isEmpty && saved.isNotEmpty;
