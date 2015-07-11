![image](https://cloud.githubusercontent.com/assets/433707/8631587/e6c54884-2782-11e5-915c-14866211e4b3.png)



Kantele application generator.

## Installation

```sh
$ npm install -g kantele
```

## Quick Start

Create an app named `foo` into directory `/tmp/foo`:

```bash
$ kantele app /tmp/foo

```

Create an app in *coffeescript*:

```bash
$ kantele app -c /tmp/foo
```

Install dependencies:

```bash
$ cd /tmp/foo && npm install
```

Create a component (when inside the app's main folder):

```bash
$ kantele cmp my-component

```

## License

[MIT](LICENSE)
