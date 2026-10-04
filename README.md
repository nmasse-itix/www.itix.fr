# www.itix.fr

## Netlify CLI

```sh
npm install -g netlify-cli
netlify login
netlify link
netlify status
```

## How to update this website

Create a new branch:

```sh
git checkout -b "$(date +%F)-update"
```

Create a new page (in english or in french):

```sh
hugo new content content/english/speaking/my-wonderful-event.md
hugo new content content/french/speaking/my-wonderful-event.md
```

English pages that are not translated are automatically published in the
french site too (see the `module.mounts` section of `config.yaml`).

Check locally that your changes are OK:

```sh
hugo server -D &
```

Commit your changes:
```sh
git add .
git commit -m "$(date +%F) update"
git push --set-upstream origin "$(date +%F)-update"
```

Go on [GitHub](https://github.com/nmasse-itix/www.itix.fr) and create a new pull
request based on this new branch.

Netlify will provision a dedicated instance for this new pull request. 
The URL will be posted in a comment in the PR. 

Check that the modifications are OK.

Merge the pull request

Delete the remote branch. 

Change back to the `master` branch locally:

```sh
git checkout master
git pull
```

Delete the old branch:

```sh
git branch -d "$(date +%F)-update"
```

## Theme

The theme lives directly in this repository (`layouts`, `assets`, `i18n` and
`static` directories). It was previously maintained as a git submodule in
[hugo-theme-itix](https://github.com/nmasse-itix/hugo-theme-itix), whose
history has been merged in this repository.

It is derived from [hugo-theme-diary](https://github.com/amazingrise/hugo-theme-diary)
and released under the MIT license (see [LICENSE-theme](LICENSE-theme)).

## How to change the Chroma style for syntax highlighting

```sh
hugo gen chromastyles --style=borland > assets/css/chroma.css
```
