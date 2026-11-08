import { useId } from "react";

type Props = {
  label: string;
  value: string;
  onChange: (value: string) => void;
  // Mensagens da API para este campo ("já está em uso"): aparecem embaixo, como frase.
  errors?: string[];
  hint?: string;
  type?: string;
  autoComplete?: string;
};

// Campo de formulário com rótulo, dica e erros ligados ao campo para o leitor de tela.
export function TextField({
  label,
  value,
  onChange,
  errors = [],
  hint,
  type = "text",
  autoComplete,
}: Props) {
  const id = useId();
  const hintId = hint ? `${id}-dica` : undefined;
  const errorId = errors.length > 0 ? `${id}-erros` : undefined;

  return (
    <div className="form-field">
      <label htmlFor={id}>{label}</label>
      {hint && (
        <p id={hintId} className="hint">
          {hint}
        </p>
      )}
      <input
        id={id}
        type={type}
        value={value}
        autoComplete={autoComplete}
        required
        aria-invalid={errorId ? true : undefined}
        aria-describedby={[hintId, errorId].filter(Boolean).join(" ") || undefined}
        onChange={(event) => onChange(event.target.value)}
      />
      {errorId && (
        <p id={errorId} className="field-error">
          {errors.map(sentence).join(" ")}
        </p>
      )}
    </div>
  );
}

// "já está em uso" vira "Já está em uso."
export function sentence(message: string) {
  return `${message.charAt(0).toUpperCase()}${message.slice(1)}.`;
}
