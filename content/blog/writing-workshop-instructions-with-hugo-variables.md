---
title: "Writing workshop instructions with Hugo, with variables in your content"
date: 2019-02-21T00:00:00+02:00
opensource: 
- Hugo
---

This is the second part of my series covering how to
[Write workshop instructions with Hugo"](../writing-workshop-instructions-with-hugo/).
In the first part, we saw how to:

- bootstrap a website with Hugo
- add content, organized in chapters and sections
- customize the look and feel to be suitable for workshop instructions

For this second part, we will add variables to our content so that we can easily
adjust the workshop instructions to different use cases.

One of the most common usage we have for variables is to deliver the same workshop
on different environments. This means URLs, username and passwords change and we
need to adjust our workshop instructions very quicky to match the new environment.

We will continue the example we started in part 1 of this serie: the Hugo mini-training.
Lets pretend that we need to change very often the GIT URL we use in the section named
"Git commit"!

First, edit your `config.toml` and add custom parameters that match your needs.
In our example, we need a GitHub username and repository to change the GIT URL
accordingly.

```ini
[params]
github_username = john
github_repository = hugo-custom-workshop
```

Change the `content/packaging/git-commit.md` to update the commit instructions:

```raw
git remote add origin git@github.com:{{</* param github_username */>}}/{{</* param github_repository */>}}.git
git push -u origin master
```

Test locally your changes new website by running:

```sh
hugo server -D
```

You can now open [localhost:1313/packaging/git-commit/](http://localhost:1313/packaging/git-commit/)
and confirm that variables have been expanded:

```md
git remote add origin git@github.com:john/hugo-custom-workshop.git
git push -u origin master
```

Congratulation, you can now change your `github_username` and
`github_repository` variables at will and see your changes reflect in your
pages!

Stay tuned for the next part of this serie!
