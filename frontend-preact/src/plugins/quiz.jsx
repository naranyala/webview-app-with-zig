import { useMemo, useState } from 'preact/hooks';
import { styles, sx, toneStyle } from '../stylex-styles.js';
import { getQuizCollection, quizCollections } from './quiz-data.js';

function scoreLabel(score, total) {
  if (score === total) return 'Perfect recall';
  if (score >= Math.ceil(total * 0.7)) return 'Strong session';
  if (score > 0) return 'Good foundation';
  return 'Ready when you are';
}

function QuizEditor() {
  const [collectionId, setCollectionId] = useState(quizCollections[0].id);
  const [query, setQuery] = useState('');
  const collection = getQuizCollection(collectionId) ?? quizCollections[0];
  const filteredQuestions = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    if (!normalizedQuery) return collection.questions;
    return collection.questions.filter((item) =>
      `${item.question} ${item.answer} ${item.tags.join(' ')}`
        .toLowerCase()
        .includes(normalizedQuery)
    );
  }, [collection, query]);

  return (
    <main className={sx('quiz-shell')}>
      <div className={sx('quiz-layout')}>
        <header className={sx('quiz-header')}>
          <div>
            <p className={sx('eyebrow')}>Deck workshop</p>
            <h1 className={sx('quiz-title')}>Quiz editor</h1>
            <p className={sx('lede')}>
              Review the bundled knowledge decks. Editing and persistence will
              arrive with the quiz authoring workflow.
            </p>
          </div>
          <div className={sx('quiz-editor-badge')}>Read only</div>
        </header>

        <section className={sx('quiz-toolbar')} aria-label="Editor controls">
          <div className={sx('selectWrap')}>
            <label
              className={sx('select-label')}
              htmlFor="quiz-editor-collection"
            >
              Collection
            </label>
            <select
              className={sx('select')}
              id="quiz-editor-collection"
              value={collection.id}
              onChange={(event) => {
                setCollectionId(event.currentTarget.value);
                setQuery('');
              }}
            >
              {quizCollections.map((item) => (
                <option value={item.id} key={item.id}>
                  {item.title}
                </option>
              ))}
            </select>
          </div>
          <label className={sx('quiz-editor-search')}>
            <span className={sx('sr-only')}>Search questions</span>
            <input
              className={sx('search-input')}
              type="search"
              placeholder="Find a prompt or topic..."
              value={query}
              onInput={(event) => setQuery(event.currentTarget.value)}
            />
          </label>
        </section>

        <section className={sx('quiz-summary')}>
          <div
            className={sx('quiz-mark', toneStyle(collection.tone, true))}
            aria-hidden="true"
          >
            {collection.icon}
          </div>
          <div className={sx('quiz-summary-copy')}>
            <p className={sx('panel-label')}>Active deck</p>
            <h2 className={sx('quiz-summary-title')}>{collection.title}</h2>
            <p className={sx('quiz-summary-description')}>
              {collection.description}
            </p>
          </div>
          <span className={sx('quiz-count')}>
            {collection.questions.length} prompts
          </span>
        </section>

        <section
          className={sx('quiz-editor-list')}
          aria-label={`${collection.title} prompts`}
        >
          {filteredQuestions.map((item) => (
            <article className={sx('quiz-editor-row')} key={item.id}>
              <span className={sx('quiz-number')}>
                {String(collection.questions.indexOf(item) + 1).padStart(
                  2,
                  '0'
                )}
              </span>
              <div>
                <h3 className={sx('quiz-row-title')}>{item.question}</h3>
                <p className={sx('quiz-row-text')}>{item.answer}</p>
              </div>
              <span className={sx('difficulty', toneStyle(collection.tone))}>
                {item.difficulty}
              </span>
            </article>
          ))}
          {filteredQuestions.length === 0 && (
            <p className={sx('quiz-empty')}>No prompts match that search.</p>
          )}
        </section>
      </div>
    </main>
  );
}

export function Quiz({ mode = 'session' }) {
  if (mode === 'editor') return <QuizEditor />;

  const [collectionId, setCollectionId] = useState(quizCollections[0].id);
  const [questionIndex, setQuestionIndex] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [known, setKnown] = useState(() => new Set());
  const [query, setQuery] = useState('');

  const collection = getQuizCollection(collectionId) ?? quizCollections[0];
  const question = collection.questions[questionIndex];
  const progress = Math.round(
    ((questionIndex + 1) / collection.questions.length) * 100
  );
  const filteredQuestions = useMemo(() => {
    const normalizedQuery = query.trim().toLowerCase();
    if (!normalizedQuery) return collection.questions;
    return collection.questions.filter((item) =>
      `${item.question} ${item.answer} ${item.tags.join(' ')}`
        .toLowerCase()
        .includes(normalizedQuery)
    );
  }, [collection, query]);

  function selectCollection(event) {
    setCollectionId(event.currentTarget.value);
    setQuestionIndex(0);
    setRevealed(false);
    setKnown(new Set());
    setQuery('');
  }

  function showQuestion(index) {
    setQuestionIndex(index);
    setRevealed(false);
  }

  function markKnown() {
    setKnown((current) => {
      const next = new Set(current);
      next.add(question.id);
      return next;
    });
    setRevealed(true);
  }

  function nextQuestion() {
    setQuestionIndex((current) => (current + 1) % collection.questions.length);
    setRevealed(false);
  }

  function resetSession() {
    setQuestionIndex(0);
    setRevealed(false);
    setKnown(new Set());
  }

  return (
    <main className={sx('quiz-shell')}>
      <div className={sx('quiz-layout')}>
        <header className={sx('quiz-header')}>
          <div>
            <p className={sx('eyebrow')}>Recall lab</p>
            <h1 className={sx('quiz-title')}>Quiz decks</h1>
            <p className={sx('lede')}>
              Short prompts for learning tools, techniques, and the ideas behind
              them.
            </p>
          </div>
          <div className={sx('quiz-score')}>
            <strong className={sx('quiz-score-strong')}>{known.size}</strong>
            <span>known</span>
          </div>
        </header>

        <section
          className={sx('quiz-collection')}
          aria-label="Quiz collections"
        >
          <div className={sx('selectWrap')}>
            <label className={sx('select-label')} htmlFor="quiz-collection">
              Collection
            </label>
            <select
              className={sx('select')}
              id="quiz-collection"
              value={collection.id}
              onChange={selectCollection}
            >
              {quizCollections.map((item) => (
                <option value={item.id} key={item.id}>
                  {item.title}
                </option>
              ))}
            </select>
          </div>
          <div
            className={sx('quiz-mark', toneStyle(collection.tone, true))}
            aria-hidden="true"
          >
            {collection.icon}
          </div>
          <div className={sx('quiz-copy')}>
            <strong className={sx('quiz-copy-strong')}>
              {collection.shortTitle}
            </strong>
            <span className={sx('quiz-copy-span')}>
              {collection.description}
            </span>
          </div>
          <button
            type="button"
            className={sx('quiz-button', 'quiz-secondary')}
            onClick={resetSession}
          >
            Reset
          </button>
        </section>

        <div className={sx('quiz-progress')}>
          <div className={sx('quiz-progress-track')}>
            <span
              className={sx('quiz-progress-fill')}
              style={{ width: `${progress}%` }}
            />
          </div>
          <span>
            {String(questionIndex + 1).padStart(2, '0')} /{' '}
            {String(collection.questions.length).padStart(2, '0')}
          </span>
        </div>

        <section className={sx('quiz-grid')}>
          <article className={sx('quiz-card', 'panel')} aria-live="polite">
            <div className={sx('quiz-topline')}>
              <span className={sx('difficulty', toneStyle(collection.tone))}>
                {question.difficulty}
              </span>
              <span>{question.tags.join(' / ')}</span>
            </div>
            <p className={sx('quiz-kicker')}>
              Prompt {String(questionIndex + 1).padStart(2, '0')}
            </p>
            <h2 className={sx('quiz-question-title')}>{question.question}</h2>
            {revealed ? (
              <div className={sx('quiz-answer')} role="status">
                <p className={sx('quiz-answer-label')}>Answer</p>
                <p className={sx('quiz-answer-text')}>{question.answer}</p>
                <p className={sx('quiz-explanation')}>{question.explanation}</p>
              </div>
            ) : (
              <button
                type="button"
                className={sx('quiz-button', 'quiz-primary')}
                onClick={() => setRevealed(true)}
              >
                Reveal answer
                <span aria-hidden="true">↗</span>
              </button>
            )}
            <div className={sx('quiz-actions')}>
              <button
                type="button"
                className={sx('quiz-button', 'quiz-secondary')}
                onClick={() =>
                  showQuestion(
                    (questionIndex - 1 + collection.questions.length) %
                      collection.questions.length
                  )
                }
              >
                Previous
              </button>
              {revealed && (
                <button
                  type="button"
                  className={sx('quiz-button', 'quiz-known')}
                  onClick={markKnown}
                >
                  {known.has(question.id) ? 'Marked known' : 'I knew this'}
                </button>
              )}
              <button
                type="button"
                className={sx('quiz-button', 'quiz-primary')}
                onClick={nextQuestion}
              >
                Next question <span aria-hidden="true">→</span>
              </button>
            </div>
          </article>

          <aside
            className={sx('quiz-index', 'panel')}
            aria-label="Question index"
          >
            <div className={sx('quiz-index-heading')}>
              <div>
                <p className={sx('panel-label')}>Deck index</p>
                <strong className={sx('quiz-index-title')}>
                  {scoreLabel(known.size, collection.questions.length)}
                </strong>
              </div>
              <span>{collection.questions.length} cards</span>
            </div>
            <label className={sx('quiz-search')}>
              <span className={sx('sr-only')}>Search questions</span>
              <input
                className={sx('search-input')}
                type="search"
                placeholder="Search this deck..."
                value={query}
                onInput={(event) => setQuery(event.currentTarget.value)}
              />
            </label>
            <div className={sx('quiz-question-list')}>
              {filteredQuestions.map((item) => {
                const index = collection.questions.indexOf(item);
                return (
                  <button
                    type="button"
                    className={sx(
                      'quiz-question',
                      index === questionIndex && styles.quizQuestionActive
                    )}
                    onClick={() => showQuestion(index)}
                    key={item.id}
                  >
                    <span className={sx('quiz-question-number')}>
                      {String(index + 1).padStart(2, '0')}
                    </span>
                    <strong className={sx('quiz-question-text')}>
                      {item.question}
                    </strong>
                    {known.has(item.id) && (
                      <b className={sx('quiz-known-mark')} title="Known">
                        ✓
                      </b>
                    )}
                  </button>
                );
              })}
              {filteredQuestions.length === 0 && (
                <p className={sx('quiz-empty')}>
                  No prompts match that search.
                </p>
              )}
            </div>
          </aside>
        </section>
      </div>
    </main>
  );
}
