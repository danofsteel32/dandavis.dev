from argparse import ArgumentParser
from datetime import date as Date
from datetime import datetime
from dataclasses import dataclass
from pathlib import Path
import jinja2
from bs4 import BeautifulSoup as bs


jinja_env = jinja2.Environment(loader=jinja2.FileSystemLoader("src"), autoescape=True)

HOME_RECENT_POSTS = 10


@dataclass
class Post:
    date: Date
    description: str
    last_updated: datetime
    slug: str
    title: str

    @classmethod
    def from_html(cls, template_name: str, html: str):
        date, description, last_updated = None, None, None
        slug = template_name.split("/")[-1].split(".")[0]
        soup = bs(html, "html.parser")
        title = soup.find("title").get_text()
        meta_tags = soup.find_all("meta")
        for tag in meta_tags:
            name = tag.get("name")
            match name:
                case "description":
                    description = tag.get("content")
                case "date":
                    date = Date.fromisoformat(tag.get("content"))
                case "last_updated":
                    last_updated = datetime.fromisoformat(tag.get("content"))
        if not all([date, description, last_updated]):
            raise TypeError("date, description, last_updated cannot be None")
        return cls(
            date=date,
            description=description,
            last_updated=last_updated,
            title=title,
            slug=slug,
        )


def render_template(template_name: str, context: dict | None = None):
    context = context if context else {}
    template = jinja_env.get_template(template_name)
    print(f"RENDER {template_name}")
    return template.render(context)


def main(full_rebuild: bool = False):
    # First render all posts, building up posts context for the recent posts section
    # Then render hire.html, finally render index.html
    # TODO figure out partial rebuilds

    src_dir = Path("src")
    site_dir = Path("site")
    posts_dir = src_dir / "posts"
    posts = []
    for file in posts_dir.glob("*.html"):
        if file.name == "index.html":
            continue
        template_name = str(file).replace("src/", "")
        html = render_template(template_name)
        out = site_dir / template_name
        out.write_text(html)
        posts.append(Post.from_html(template_name, html))

    posts = sorted(posts, key=lambda x: x.date, reverse=True)
    posts_index = render_template("posts/index.html", dict(posts=posts))
    out = site_dir / "posts/index.html"
    out.write_text(posts_index)

    for file in src_dir.glob("*.html"):
        if file.name == "base.html":
            continue
        template_name = str(file).replace("src/", "")
        html = render_template(template_name, dict(posts=posts[:HOME_RECENT_POSTS]))
        out = site_dir / template_name
        out.write_text(html)


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument("--full-rebuild", action="store_true")
    args = parser.parse_args()
    main(args.full_rebuild)
