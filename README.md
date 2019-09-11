# www.itix.fr

## How to update this website

Create a new branch:

```sh
git checkout -b "$(date +%F)-update"
```

Create a new page:

```sh
hugo new speaking/my-wonderful-event.md
vim content/speaking/my-wonderful-event.md
```

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

## How to update the theme

You can update a theme to the latest version by executing the following command in the root directory of your project:

```
git submodule update --rebase --remote
```

## How to change the Chroma style for syntax highlighting

```sh
mkdir -p static/css
hugo gen chromastyles --style=perldoc > static/css/chroma.css
```
