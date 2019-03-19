[
  inputs: ["mix.exs", "{config,lib,test}/**/*.{ex,exs}"],
  export: [
    locals_without_parens: [
      step: 1,
      step: 2,
      tee: 1,
      tee: 2,
      check: 1,
      check: 2,
      link: 1,
      link: 2,
      skip: 2,
      instrument: 2,
      instrument: 3,
      send: 2
    ]
  ],

  locals_without_parens: [
    step: 1,
    step: 2,
    tee: 1,
    tee: 2,
    check: 1,
    check: 2,
    link: 1,
    link: 2,
    skip: 2,
    instrument: 2,
    instrument: 3,
    send: 2,
    on_exit: 1,
    raise: 1
  ]
]
