---
title: "M4 as a replacement for sed"
date: 2019-03-15T00:00:00+02:00
---

Writing a tutorial often involves to replace a placeholder in a file, such as:

*Replace FOO with the actual name of your image:*

```sh
sed 's|IMAGE_NAME|docker.io/foo/bar:latest|g' template.yaml |kubectl apply -f -
```

But this approach has several drawbacks:

- If you have to replace multiple placeholders, the sed syntax becomes cumbersome.
- If the delimiter appears in your replacement string, you will have to find another
  delimiter (such as in the previous example where the usual slash has been replaced
  by a pipe to accomodate the slash in the image name).
- The `sed` command has some subtleties between the GNU (any Linux distribution)
  and the BSD (MacOS) flavors.

For this specific use case (replacing placeholders), I would like to introduce
another tool: the `m4` command.

The `m4` command is used in the C/C++ compilation chain to replace pre-processor
directives with their actual values. Its syntax is very simple and it is present on
most Linux distributions and on MacOS by default.

Let's have a look at a very simple example:

```raw
$ cat > example <<EOF
Hello, my name is NAME and I like THING.
EOF

$ m4 -D NAME=Nicolas -D THING=beers example
Hello, my name is Nicolas and I like beers.

$ m4 -D NAME=John -D THING=wine example
Hello, my name is John and I like wine.
```

Next time you write a tutorial in which you need to replace a placeholder with
its actual value, consider the `m4` command!