# My 827K Dog Image Dataset
**TLDR: I have 90GB of high quality doggo images labeled by breed and individual**

This all started when I was working on a protoype dog training/enrichment
device with some friends. The idea was to give a voice command and then use
an ML model to classify whether the dog correctly obeyed the command and
dispense a treat. We used the
[Stanford Dogs](http://vision.stanford.edu/aditya86/ImageNetDogs) dataset
to train a model that could successfully identify whether our dogs were
sitting, standing, or laying down. My wife has a friend who owns a dog
daycare business and when she heard about what we did she reached out 
to me with an idea.

Her business was entering it's 3rd year and her client base had grown
significantly (from 20-30 to 100-150 dogs a day).
The [SAAS Platform](https://www.gingrapp.com) she used for customer
signup, reservations, employee scheduling, etc. also had a daily report card
feature. Basically each client would get an email or text message at the end
of the day containing any notes from the staff along with 10-15 pictures of
their dog taken that day. Clients loved this feature but it only was only
possible because of labor intensive manual tagging by the staff. The SAAS
platform she used was also obviously not designed to handle tagging 2000+
images at a time. The tagging page did not use any pagination and did not
resize the iphone quality images so you can imagine how slow and unresponsive
it would become trying to display thousands of ~4MB images. This meant that the
staff were spending ~8 labor-hours a day just tagging photos! She asked me if
I could come up with an automated solution using computer vision.

## Poking Around
My initial reaction was **Probably not**, but I did want to try.
So armed with my own login credentials I started poking around her gingrapp
instance to see if I could scrape all of the images and tags her staff had
uploaded over the last 2 years. With a little bit of fiddling in the browser
inspector I figured out what session cookies I needed to grab and the requests
I needed to make to get what I was after. The python script I wrote to download
the images and tags later grew into my
[Unofficial Gingr API](href=https://github.com/danofsteel32/gingr).

The obvious approach for storing the downloaded images would be a directory
per dog but since many of the images were tagged with multiple dogs it would
mean downloading potentially 100K+ images twice. Instead I chose to store the
image urls and tags in my local Postgres database in this schema.

```sql
create table image (
    image_id int generated always as identity,
        primary key (image_id),
    url text unique not null,
    date_taken date not null  -- it's in the url and is nice to have
);
create index image_date_taken_index on image(date_taken);

create table dog (
    dog_id int primary key (dog_id), -- Use same id as gingr uses
    first_name text not null,
    last_name text not null,
    breed text not null,
    birthday date not null
);

/* Intersection table because of Many-to-Many relationship between dogs
   and images. A dog is tagged in many images and an image can be tagged
   with many dogs. Also store a flag for whether or not the tag is correct
   so I can correct mis-tagged images and have an idea of how well the
   human taggers performed as a benchmark. */
create table dog_image (
    image_id int,
    foreign key (image_id) references image(image_id)
        on delete cascade,
    dog_id int,
    foreign key (dog_id) references dog(dog_id)
        on delete cascade,
    correct boolean default True,
    primary key (image_id, dog_id)
);

/* Can extract the filepath from url so no need for separate filepath column */
create or replace function path_from_url(_url text)
returns text
language plpgsql
as $$
declare
    filename text;
begin
select split_part(_url, '/', 9) into filename;
if (filename = '') then
    select split_part(_url, '/', 8) into filename;
end if;
return '/home/dan/Pictures/doggos/' || substring(filename, 1, 1) || '/'
       || substring(filename, 2, 1) || '/' || filename;
end; $$;
```

The images were hosted on Google Cloud at urls like:
```
  https://storage.googleapis.com/gingr-app-user-uploads//2021/08/03/1fb96889-201d-4a26-ae1d-bb4121b04a47-IMG_9086.jpeg
```
Which I then stored in nested directories based on the first 2 characters in
the filename. So the above filename would be saved to:
```
~/Pictures/doggos/1/f/1fb96889-201d-4a26-ae1d-bb4121b04a47-IMG_9086.jpeg
```
Most of the images are iPhone quality (4032x3024) which is way too large to
feed to an image classifier so I used
[PIL's reduce function](https://pillow.readthedocs.io/en/stable/reference/Image.html#PIL.Image.Image.reduce)
to shrink them by a factor of 4 (2 if WxH less than 2000x2000) before saving
them to disk. It a little over 2 days to download them all and came out to about 90GB.

## Analysis
The following table shows the total number of images, tags, and dogs along with
the min, max, mean, median number of tagged images per dog:

<table>
  <thead>
    <tr>
      <th>Images</th>
      <th>Tags</th>
      <th>Dogs</th>
      <th>Dogs w/ 50+ tags</th>
      <th>Min</th>
      <th>Max</th>
      <th>Mean</th>
      <th>Median</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>827017</td>
      <td>977467</td>
      <td>1499</td>
      <td>1201</td>
      <td>1</td>
      <td>8946</td>
      <td>652</td>
      <td>258</td>
    </tr>
  </tbody>
</table>

The top 20 percent of dogs as ranked by number of tagged images account for
81% of all of the images.
```sql
with top20percent as (
    select
      dog_id,
      count(image_id) as images
    from dog_image
    group by dog_id
    order by images desc limit 300
) select round(
    (select sum(images) from top20percent) /
    (select count(*) * 1.0 from image), 2) as top20;

top20
-----
0.81
```

Also people really like doodles (poodle mix). Or at least the sort of people
who take their dog to a daycare really like poodles. Almost 20% of the dogs
are some form of doodle.</p>
```sql
select count(*) as doodles
  from dog where breed like '%doodle%';

doodles
-------
278
```
The 300 dogs with less than 50 tagged images confirmed my suspicion that there
would be severe class imbalances. Looking through some of the images too I could
see that the staff had been far from perfect at tagging every dog in an image.
Some images had 5-6 dogs but only a single tag. Data quality is probably the biggest
factor in a successful image classification project so these were worrying signs.
Nevertheless now that I had the data I moved on to designing a system to try and
make use of it.

## Working Prototype
With 1499 very unbalanced classes (and that number was increasing every week) I assumed
that accuracy using standard multi-label classification would be poor.
Plus every time there was a new dog the model would have to be re-trained and that
would take the better part of a day.
I could pull the daily schedule from gingr however which allowed me to narrow it
down to a 100-150 class problem but there were 4-5 walk-ins (dogs without reservations)
every day and the model would have to be retrained. I finally settle on a
[Binary Relevance](http://palm.seu.edu.cn/zhangml/files/FCS%2717.pdf)
approach for it's flexibility. This meant I would train a classifier for each dog,
basically asking the question *Is the dog in the image?* Then when it came time
to make predictions on new images I would run each classifier against the new images.
This would give me number for every dog on whether the dog was in each image.

From there I could tweak my threshold for making tags based on the confusion matrix:
- FN (False Negative) = wrongly predicted dog not in image
- TN (True Negative) = correctly predicted dog not in image
- FP (False Positive) = wrongly predicted dog in image
- TP (True Positive) = correctly predicted dog in image

A false positive was relatively easy to correct using the staff's existing tools,
Just delete the tag. A false negative had no easy remedy so I'd rather err on the
side of being slightly over sensitive rather than over specific.
Basically the idea was to push all of the tagging labor into the review stage with
the hope that after the staff eliminated the false positives there would be enough
true positives remaining that they wouldn't have to do any manual tagging.</p>

<!-- <div style='width: 100%; display: inline-block;'> -->
<!--   <p>A couple <a href=https://arxiv.org/abs/1910.01279>Score-CAM</a> visualizations:</p> -->
<!--   <figure style='display: inline-block;'> -->
<!--     <img src=../static/images/dogs/heatmap-single.png width=194 height=201> -->
<!--     <figcaption>Single doggo</figcaption> -->
<!--   </figure> -->
<!--   <figure style='display: inline-block;'> -->
<!--     <img src=../static/images/dogs/heatmap-multi.png width=194 height=201> -->
<!--     <figcaption>Multiple doggos</figcaption> -->
<!--   </figure> -->
<!-- </div> -->
Scorecam visualization showing that left heatmap has high probability of being the
doggo on the left while the right heatmap has very low probability:

![Another Heatmap](../static/images/dogs/Ace-heatmap-demo.png)

The system I ended up with looked roughly like this in pseudo-code:
```python
CUTOFF = 8PM  # switch from today's schedule and to tomorrow's
UNTAGGED_IMAGE_THRESHOLD = 64  # wait until we at least a full batch

while True:
    poll_schedule(CUTOFF)  # returns today's or tomorrow's
    for dog in schedule:
        if not get_trained_model(dog):
            train_model(dog)
    untagged_images = get_untagged_images()
    if len(untagged_images) >= UNTAGGED_IMAGE_THRESHOLD:
        for dog in schedule:
            model = get_trained_model(dog)
            model.predict(untagged_images)
        preds = aggregate_predictions()
        post_predictions(preds)
    sleep(5 minutes)
```

## Conclusion: Did it Work?
Kind of. It wasn't a fully automated system but it did significantly cut the
labor-hours spent tagging from 6-8hrs to ~1hr. The system was very fragile though.
If the schedule was not accurate (and it almost never was) accuracy would drop.
If the human reviewers were not perfect the predictions would become progressively
worse in a bad data feedback loop. Ultimately moving to a production ready system
would have cost way more than the daycare was willing to pay so I stopped at the
prototype stage. The daycare eventually solved their labor problem by simply not
taking thousands of pictures every day.
