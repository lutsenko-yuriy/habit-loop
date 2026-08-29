/// Maximum accepted display-name length (HAB-232) — caps what eventually
/// reaches notification copy. Enforced both by the platform bodies'
/// `LengthLimitingTextInputFormatter` and, defensively, in `EnterNameScreen`.
const int enterNameMaxLength = 40;
